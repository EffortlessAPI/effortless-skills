# effortless-rulebook-devops — templates

Copy-pasteable skeletons for the four-tier model (§0 of SKILL.md). **Starting
points** — adapt names/paths per project. dev + staging are localhost; beta +
production are remote. Every mutating script guards its target; `init-db` is dev-only,
and staging/beta/production are only ever written by `apply.sh`.

Keep one shell command per agent Bash call when running these; the scripts themselves
chain freely.

---

## `scripts/devops/_lib.sh` — guards + tier→URL resolution

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve psql/pg_dump for the LOCAL server version (override with PG_BIN=...).
PG_BIN="${PG_BIN:-}"
if [[ -z "$PG_BIN" ]]; then
  for d in /opt/homebrew/opt/postgresql@18/bin /usr/local/opt/postgresql@18/bin \
           /usr/lib/postgresql/18/bin ""; do
    if [[ -x "$d/psql" || ( -z "$d" && -x "$(command -v psql || true)" ) ]]; then
      PG_BIN="${d:-$(dirname "$(command -v psql)")}"; break
    fi
  done
fi
PSQL="$PG_BIN/psql"; PGDUMP="$PG_BIN/pg_dump"

# LOCAL tiers (dev + staging). REMOTE tiers reached via tunnel (see ensure-remote-tunnel.sh).
DEV_URL="${DATABASE_URL:?set DATABASE_URL (dev, localhost)}"
STAGING_URL="${STAGING_DATABASE_URL:-postgresql://postgres@localhost:5432/${DEV_DB:-app}_staging}"
BETA_URL="${BETA_DATABASE_URL:-}"          # remote (or a localhost tunnel endpoint)
PROD_URL="${PRODUCTION_DATABASE_URL:-}"    # remote (or a localhost tunnel endpoint)

# HARD localhost guard — used for anything init-db/DROP-adjacent and for the LOCAL tiers.
assert_localhost() {
  local url="$1" host
  host="$(printf '%s' "$url" | sed -E 's#^[a-z]+://([^@/]*@)?([^:/?]+).*#\2#')"
  case "$host" in
    localhost|127.0.0.1|::1|"") : ;;
    *) echo "REFUSING non-localhost host: $host" >&2; exit 2 ;;
  esac
}
# dev + staging MUST be localhost. beta/prod may be remote (guarded differently at apply time).
assert_localhost "$DEV_URL"
assert_localhost "$STAGING_URL"

url_for() { case "$1" in
  dev) printf '%s' "$DEV_URL";; staging) printf '%s' "$STAGING_URL";;
  beta|uat) printf '%s' "$BETA_URL";; production|prod) printf '%s' "$PROD_URL";;
  *) echo "unknown tier: $1" >&2; return 1;; esac; }
```

---

## `scripts/devops/00-create-local-envs.sh` — create the localhost staging DB (never init-db's it)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
db_name() { printf '%s' "$1" | sed -E 's#.*/([^/?]+).*#\1#'; }
ADMIN_URL="postgresql://postgres@localhost:5432/postgres"

name="$(db_name "$STAGING_URL")"
exists="$("$PSQL" -tA "$ADMIN_URL" -c "SELECT 1 FROM pg_database WHERE datname='$name';")"
if [[ "$exists" != "1" ]]; then
  echo "creating $name"; "$PSQL" "$ADMIN_URL" -c "CREATE DATABASE \"$name\";"
else echo "$name exists"; fi
echo "NOTE: staging is NOT init-db'd. Bring it up with: apply.sh staging  (000-seed + migrations)."
# beta/production are REMOTE — provisioned on their box, not here.
```

---

## `migrations/000-seed-rulebook/up.sql` — full schema, idempotent (generated ONCE)

Generate from the freshly-built `00–05*.sql`, **schema-only**, made idempotent. This
runs once at genesis; after it, deltas become new migrations — never regenerate it.

```sql
-- 000-seed-rulebook: the ENTIRE init-db schema stack, idempotent. Genesis only.
-- Empty DB + this + every later migration == current dev schema.
BEGIN;
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  id text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now(), notes text);

-- <<< concatenated, idempotent 00–05 DDL (schema only, no operational rows) >>>
--   CREATE TABLE IF NOT EXISTS ...            (all base tables)
--   CREATE OR REPLACE VIEW vw_* ...           (all views, security_invoker as dev has it)
--   CREATE OR REPLACE FUNCTION ...            (calc_/get_ functions)
--   ALTER TABLE ... ENABLE ROW LEVEL SECURITY; (guarded)
--   CREATE POLICY ... ;  GRANT ... ;

INSERT INTO public.schema_migrations (id, notes)
VALUES ('000-seed-rulebook', 'Full init-db schema baseline (genesis)')
ON CONFLICT (id) DO NOTHING;
COMMIT;
```

Generate helper (run once; then this script is retired):

```bash
# scripts/devops/regenerate-seed.sh — ONE-TIME genesis only. Do NOT re-run to "rebaseline".
source "$(dirname "$0")/_lib.sh"
[[ -f migrations/000-seed-rulebook/up.sql ]] && { echo "seed exists — deltas go in new migrations"; exit 1; }
"$PGDUMP" --schema-only --no-owner --no-privileges "$DEV_URL" \
  | scripts/devops/idempotentize.sed > migrations/000-seed-rulebook/up.sql
echo "Review the seed for idempotency before applying. This is the ONLY time it is generated."
```

---

## A hand-derived migration — `migrations/NNNN-<slug>/up.sql` (self-registering)

The `up.sql` is **authored**, not a diff dump. It must self-register in the catalog
**and** stamp an `erb_versions` changelog row.

```sql
-- NNNN-<slug>: <what this release changes>. Hand-derived; schema + config only.
BEGIN;

-- 1) Schema DDL (additive; idempotent) --------------------------------------
-- CREATE TABLE IF NOT EXISTS ... ; ALTER TABLE ... ADD COLUMN IF NOT EXISTS ... ;
-- CREATE OR REPLACE VIEW vw_... ; CREATE OR REPLACE FUNCTION ... ;

-- 2) Config / reference DATA (targeted upserts + deletes; NEVER operational rows) --
-- INSERT INTO public.some_config (id, ...) VALUES (...) ON CONFLICT (id) DO UPDATE SET ...;
-- DELETE FROM public.some_config WHERE id = '...';   -- prune rows no longer in the rulebook

-- 3) RLS + grants lost when views are recreated -----------------------------
-- GRANT SELECT ON vw_... TO iui_anon;  CREATE POLICY ... ;

-- 4) Self-register in the promotion catalog ---------------------------------
INSERT INTO public.promotion_migrations (id, slug, notes)
VALUES ('NNNN-<slug>', '<slug>', '<message>')
ON CONFLICT (id) DO NOTHING;

-- 5) Changelog row (label only — NEVER the version authority) ----------------
INSERT INTO public.erb_versions (erb_version_id, version, commit_message, migration_id)
VALUES ('vYYYY.MM.DD-NNNN', 'vYYYY.MM.DD-NNNN', '<git commit message>', 'NNNN-<slug>')
ON CONFLICT (erb_version_id) DO NOTHING;

-- 6) Record in the ledger ---------------------------------------------------
INSERT INTO public.schema_migrations (id, notes) VALUES ('NNNN-<slug>', '<message>')
ON CONFLICT (id) DO NOTHING;
COMMIT;
```

---

## `scripts/devops/cut-version.sh` — "Take Snapshot": git message → version + empty scaffold

**No diffing here.** Cut a version and scaffold an EMPTY `up.sql` for the agent to fill.

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
SLUG="${1:?migration slug required}"
MSG="${2:-$(git log -1 --pretty=%s)}"          # default: most recent git commit message

effortless build                                # ensure dev = HEAD (Leopold loop)
NNNN="$(printf '%04d' "$(ls -d migrations/[0-9]* 2>/dev/null | wc -l)")"
MIG="migrations/${NNNN}-${SLUG}"; mkdir -p "$MIG"
[[ -f "$MIG/up.sql" ]] || printf -- '-- %s-%s: %s\n-- Author this by hand (diff to discover, author to derive).\nBEGIN;\nCOMMIT;\n' \
  "$NNNN" "$SLUG" "$MSG" > "$MIG/up.sql"

VER="v$(git log -1 --pretty=%cd --date=format:%Y.%m.%d)-$NNNN"
"$PSQL" "$DEV_URL" -c "INSERT INTO public.erb_versions
  (erb_version_id,version,commit_message,migration_id,created_by)
  VALUES ('$VER','$VER','$MSG','${NNNN}-${SLUG}','deployment-page')
  ON CONFLICT (erb_version_id) DO NOTHING;"
echo "Scaffolded $MIG/up.sql and cut $VER — now AUTHOR the migration SQL by hand."
```

---

## `scripts/devops/analyze-diff.sh` — READ-ONLY discovery aid (diff proposes; you dispose)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
A="$(url_for "${1:-dev}")"; B="$(url_for "${2:-staging}")"
# Side-by-side schema-only dumps for a human/agent to read — NOT a migration.
"$PGDUMP" --schema-only --no-owner --no-privileges "$A" > /tmp/_a.sql
"$PGDUMP" --schema-only --no-owner --no-privileges "$B" > /tmp/_b.sql
diff -u /tmp/_b.sql /tmp/_a.sql || true         # what B lacks vs A (dev)
echo "^^ discovery only. Author migrations/NNNN-<slug>/up.sql by hand from this."
```

---

## `scripts/devops/canonicalize-schema.py` — order-independent fingerprint

```python
#!/usr/bin/env python3
# Normalize a `pg_dump --schema-only` stream so equal schemas hash equal regardless
# of statement order / volatile noise. Print a stable md5. Used by the matrix's fast
# signal for EVERY tier (never raw pg_dump md5 — that reports false drift).
import sys, re, hashlib
stmts, buf = [], []
for line in sys.stdin:
    if line.startswith('--') or line.strip() == '': continue
    buf.append(line.rstrip())
    if line.rstrip().endswith(';'):
        s = re.sub(r'\s+', ' ', ' '.join(buf)).strip()
        stmts.append(s); buf = []
stmts.sort()                                     # order-independent
print(hashlib.md5('\n'.join(stmts).encode()).hexdigest())
```

---

## `backend/src/lib/devops/erb-version.ts` — version DERIVED from the ledger

```ts
// The version is COMPUTED from the ledger on every read — never stored as authority.
// HEAD = newest migration in the catalog; an env's version = newest in ITS schema_migrations.
export async function versionOf(tier: Tier): Promise<VersionInfo> {
  const applied = await ledgerIds(tier);                 // SELECT id FROM schema_migrations
  const head = catalogIds().at(-1)!;                     // newest migrations/NNNN-* folder
  const latest = applied.at(-1) ?? null;                 // this tier's high-water mark
  const label = await changelogLabel(latest);            // erb_versions row, or fall back to id
  return { tier, migrationId: latest, label: label ?? latest, isHead: latest === head };
}
// NEVER read a stored project_meta/erb_versions row AS the version. erb_versions is a
// human changelog only; a missing row degrades to the migration id, never a stale number.
```

---

## `backend/src/lib/devops/code-version.ts` — the second axis

```ts
// Code build axis. dev = HEAD; staging = HEAD by construction (dev's code); beta/prod
// = the box's OWN running sha, read from its health stamp; unreachable => 'unknown'.
export async function codeBuildOf(tier: Tier): Promise<string> {
  if (tier === 'dev' || tier === 'staging') return BUILD_INFO.sha;   // HEAD
  try {
    const r = await fetchWithTimeout(`${boxBase(tier)}/api/dev/health/build`, 2500);
    return (await r.json()).sha ?? 'unknown';
  } catch { return 'unknown'; }                                       // never guess
}
```

---

## Deployment Management — `/api/admin/deployment/matrix` (two axes; booleans/shas only)

```js
// Reads each tier's schema_migrations + a CANONICAL schema fingerprint + code build.
// Ships booleans/timestamps/short shas ONLY — never a connection string. Dev-only.
app.get('/api/admin/deployment/matrix', requireAdmin, devOnly, async (_req, res) => {
  const tiers = activeTiers();                     // e.g. ['dev','staging','beta','production']
  const onDisk = listMigrationsOnDisk();           // ['000-seed-rulebook','0001-...', ...]
  const head = { id: onDisk.at(-1), hash: await canonicalHash('dev') };
  const ledgers = {}, hashes = {}, code = {}, ver = {};
  for (const t of tiers) {
    ledgers[t] = await ledgerOf(t);                // [{id, applied_at}]
    hashes[t]  = await canonicalHash(t);           // order-independent fingerprint
    code[t]    = await codeBuildOf(t);             // second axis
    ver[t]     = await versionOf(t);               // DERIVED from ledger
  }
  const migrations = onDisk.map(id => {
    const row = { id };
    for (const t of tiers) {
      const applied = ledgers[t].some(r => r.id === id);
      row[t] = applied
        ? (hashes[t] === head.hash ? 'applied' : 'drift')   // fingerprint beats ledger
        : 'pending';
      row[t + 'At'] = ledgers[t].find(r => r.id === id)?.applied_at ?? null;
    }
    return row;
  });
  const orderViolation = !isMonotonic(tiers, ver); // dev >= staging >= beta >= production
  res.json({ tiers, head, migrations,
             version: ver, codeBuild: code, orderViolation });   // no URLs, ever
});
```

### Client — matrix + two-axis cards

```js
const ICON = { applied:'✅', pending:'⏳', 'not-built':'⬜', drift:'⚠', head:'✔ HEAD' };
function renderCards(m) {
  return m.tiers.map(t => card(
    t.toUpperCase(),
    row('DB version',  m.version[t].label + (m.version[t].isHead ? ' (HEAD)' : '')),
    row('Code build',  m.codeBuild[t] === m.head.sha ? m.codeBuild[t] + ' (HEAD)' : m.codeBuild[t]),
    t.match(/beta|prod/) && pushCodeButton(t, m.codeBuild[t], m.head.sha),  // "prodSha → headSha"
  ));
}
function renderMatrix(m) {
  const head = tr(th('Migration'), ...m.tiers.map(t => th(t.toUpperCase())));
  const body = m.migrations.map(r => tr(td(code(r.id)), ...m.tiers.map(t => td(ICON[r[t]] ?? r[t]))));
  return [ m.orderViolation ? alert('⚠ ORDER VIOLATION — a downstream tier is ahead of an upstream one') : '',
           table('matrix', head, ...body) ];
}
```

---

## Environment switcher + dev-only endpoints

### Client — bottom-left floaty (localhost dev only; per-stage tint)

```js
if (location.hostname === 'localhost' && window.__DEV_MODE__) {
  const stage = window.__ACTIVE_ENV__ || 'dev';
  document.body.classList.add('stage-' + stage);
  const fab = el('div', { class:'devops-fab stage-'+stage });
  fab.append(
    el('div', { class:'fab-stage' }, 'ENV: ' + stage.toUpperCase()),
    btn('Dev',     () => switchEnv('dev')),
    btn('Staging', () => switchEnv('staging')),
    btn('Beta',    () => switchEnv('beta')),        // only if the tier exists
    btn('Prod',    () => switchEnv('production')),  // dev CAN reach prod (read/diff); prod can't reach back
    link('Deployment', '#admin-deployment'),
    link('Versions',   '#admin-versions'),
  );
  document.body.append(fab);
}
async function switchEnv(env) {                     // server-side re-point; browser never sees a URL
  await fetch('/api/dev/devops/active-env', { method:'POST', credentials:'include',
    headers:{'Content-Type':'application/json'}, body: JSON.stringify({ env }) });
  location.reload();
}
```

```css
.stage-dev        .topbar { box-shadow: inset 0 -3px 0 #2e9e5b; }  /* green  */
.stage-staging    .topbar { box-shadow: inset 0 -3px 0 #d9a200; }  /* amber  */
.stage-beta       .topbar { box-shadow: inset 0 -3px 0 #2f6fd0; }  /* blue   */
.stage-production .topbar { box-shadow: inset 0 -3px 0 #c0392b; }  /* red    */
.devops-fab { position: fixed; left: 14px; bottom: 14px; z-index: 9999;
  display:flex; gap:6px; flex-direction:column; background:#11140f; color:#d6e2c8;
  padding:10px; border-radius:10px; font:12px ui-monospace,Menlo,monospace; }
```

### Server — dev-only endpoints (404 when the running copy is a deployed remote)

```js
const devOnly = (req,res,next) => DEV_MODE ? next() : res.status(404).end();

app.post('/api/dev/devops/active-env', requireAdmin, devOnly, (req,res) => {
  const env = activeTiers().includes(req.body?.env) ? req.body.env : 'dev';
  reconnectPool(urlFor(env));                    // server-side only; browser never sees the URL
  res.json({ env });
});
app.post('/api/dev/devops/analyze',    requireAdmin, devOnly, runReadOnlyDiff); // discovery aid
app.post('/api/dev/devops/apply',      requireAdmin, devOnly, applyToTarget);   // apply.sh (staging/beta/prod)
app.post('/api/dev/devops/push-code',  requireAdmin, devOnly, deployRemoteCode);// deploy-remote-code.sh
app.post('/api/dev/devops/test',       requireAdmin, devOnly, runTestsFor);     // green gate
app.post('/api/dev/devops/drift',      requireAdmin, devOnly, deepDriftReport); // on-demand deep check
app.post('/api/dev/devops/snapshot',   requireAdmin, devOnly, cutVersion);      // Take Snapshot
// NOTE: there is deliberately NO "save to staging/production" endpoint. Migrations only.
```

`apply` to a remote must require the latest **staging** `test` run to be green, and
respect monotonic order, before it runs.

---

## Remote operations (beta / production on a live box)

```bash
# scripts/devops/ensure-remote-tunnel.sh — open an SSH tunnel to the box, export *_DATABASE_URL
#   as a localhost:PORT endpoint that forwards to the remote Postgres.
# scripts/devops/deploy-remote-code.sh <beta|production> — rsync working tree → box,
#   install deps, build frontend, restart backend + reload web server. CODE AXIS ONLY.
#   Prints "remoteSha → headSha" before acting. NEVER runs init-db; NEVER touches the DB.
# scripts/devops/restore-soak-env.sh <beta|uat> — restore the soak env from a PRODUCTION
#   snapshot (expected/routine). Allowed: prod → beta/uat, prod → staging. NEVER the reverse.
```

Applying a migration on the box uses the **same** `migrations/apply.sh` runner, run
**on the box** after rsync'ing `postgres/migrations/`. `apply.sh` hard-refuses to run
`init-db` and only ever appends to the ledger.

---

## `scripts/devops/run-tests.sh <env>` — the green-light gate

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
URL="$(url_for "${1:?env: dev|staging|beta|production}")"
DATABASE_URL="$URL" npm run test:conformance     # ERB conformance suite from rulebook _meta
DATABASE_URL="$URL" npm run test:ui-smoke        # UI smokes on top
```

Expected results that PROVE the model:
- **DB-change release:** staging (and beta/prod) FAIL before the migration, green after.
- **No-DB-change release:** green everywhere the code axis is current, no migration needed.
- **Only an all-green staging run unlocks "Promote to production."**
