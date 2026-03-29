# effortless-rulebook-devops — templates

Copy-pasteable skeletons for the 3-layer localhost model. **These are starting
points** — adapt names/paths per project. Every script assumes localhost-only and
guards accordingly. Keep one shell command per Bash call when running them via the
agent (per the Banyan tool rules); the scripts themselves chain freely.

---

## `scripts/devops/_lib.sh` — shared guards + env

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

DEV_URL="${DATABASE_URL:?set DATABASE_URL (dev, localhost)}"
STAGING_URL="${STAGING_DATABASE_URL:-postgresql://postgres@localhost:5432/${DEV_DB:-app}_staging}"
PROD_URL="${PRODUCTION_DATABASE_URL:-postgresql://postgres@localhost:5432/${DEV_DB:-app}_production}"

# HARD localhost guard — refuse anything that is not a local host.
assert_localhost() {
  local url="$1" host
  host="$(printf '%s' "$url" | sed -E 's#^[a-z]+://([^@/]*@)?([^:/?]+).*#\2#')"
  case "$host" in
    localhost|127.0.0.1|::1|"") : ;;
    *) echo "REFUSING non-localhost host: $host" >&2; exit 2 ;;
  esac
}
for u in "$DEV_URL" "$STAGING_URL" "$PROD_URL"; do assert_localhost "$u"; done
```

---

## `scripts/devops/00-create-local-envs.sh` — three local DBs (never init-db's the extras)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
db_name() { printf '%s' "$1" | sed -E 's#.*/([^/?]+).*#\1#'; }
ADMIN_URL="postgresql://postgres@localhost:5432/postgres"

for url in "$STAGING_URL" "$PROD_URL"; do
  name="$(db_name "$url")"
  exists="$("$PSQL" -tA "$ADMIN_URL" -c "SELECT 1 FROM pg_database WHERE datname='$name';")"
  if [[ "$exists" != "1" ]]; then
    echo "creating $name"; "$PSQL" "$ADMIN_URL" -c "CREATE DATABASE \"$name\";"
  else echo "$name exists"; fi
done
echo "NOTE: staging/production are NOT init-db'd. Bring them up with migrations/apply.sh."
```

---

## `migrations/000-seed-rulebook/up.sql` — full schema, idempotent (generated)

Generate from the freshly-built `dev-postgres-bootstrap/00–05*.sql`, schema-only,
made idempotent. Conceptually:

```sql
-- 000-seed-rulebook: the ENTIRE init-db schema stack, idempotent.
-- An empty DB + this + every later migration == current dev schema.
BEGIN;
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  id text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now(), notes text);

-- <<< concatenated, idempotent 00–05 DDL goes here >>>
--   CREATE TABLE IF NOT EXISTS ...   (all base tables)
--   CREATE OR REPLACE VIEW vw_* ...  (all views)
--   CREATE OR REPLACE FUNCTION ...   (calc_/get_ functions)
--   ALTER TABLE ... ENABLE ROW LEVEL SECURITY;  (guarded)
--   CREATE POLICY IF NOT EXISTS ...

INSERT INTO public.schema_migrations (id, notes)
VALUES ('000-seed-rulebook', 'Full init-db schema baseline')
ON CONFLICT (id) DO NOTHING;
COMMIT;
```

Build helper (regenerate at each rebaseline):

```bash
# scripts/devops/regenerate-seed.sh  — schema-only dump of dev → seed migration
source "$(dirname "$0")/_lib.sh"
"$PGDUMP" --schema-only --no-owner --no-privileges "$DEV_URL" \
  | scripts/devops/idempotentize.sed > migrations/000-seed-rulebook/up.sql
echo "Review the seed for idempotency before applying."
```

---

## ERBVersions — version log DDL

```sql
CREATE TABLE IF NOT EXISTS public.erb_versions (
  erb_version_id   text PRIMARY KEY,            -- e.g. 'v2026.06.14.1'
  version          text NOT NULL,               -- human label
  commit_message   text NOT NULL,
  migration_id     text,                        -- migrations/NNNN-slug it produced
  rulebook_build   text,                        -- effortless build stamp at cut time
  dev_schema_hash  text,                        -- hash of dev schema at cut time
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       text
);
```

---

## `scripts/devops/cut-version.sh` — build → diff → version row

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
MSG="${1:?commit message required}"; SLUG="${2:?migration slug required}"

effortless build                                   # 1. Leopold loop: dev = HEAD
NNNN="$(printf '%04d' $(( $(ls -d migrations/[0-9]* 2>/dev/null | wc -l) )) )"
MIG="migrations/${NNNN}-${SLUG}"
bash scripts/devops/generate-diff.sh "$MIG"        # 2. dev init-db ↔ staging → up.sql
echo ">> Review $MIG/up.sql, then it will be recorded as a version."

VER="v$(date +%Y.%m.%d).$NNNN"                      # (pass date in; do not rely on Date.now in agents)
"$PSQL" "$DEV_URL" -c "INSERT INTO public.erb_versions
  (erb_version_id,version,commit_message,migration_id,created_by)
  VALUES ('$VER','$VER','$MSG','${NNNN}-${SLUG}','devops');"
echo "Cut $VER → $MIG"
```

`generate-diff.sh` is a thin diff of **dev's init-db schema** vs **staging's current
schema** (use `migra` if installed, else side-by-side `pg_dump --schema-only` to
hand-reconcile) writing `<MIG>/up.sql`. Mirror the existing project `generate-diff.sh`.

---

## Deployment matrix endpoint + page

### Server — `/api/admin/deployment/matrix` (booleans only; never leak URLs)

```js
// Reads each LOCAL env's schema_migrations + a cheap schema hash. Dev-readable
// always; in a deployed-prod build it returns only that prod's own ledger.
app.get('/api/admin/deployment/matrix', requireAdmin, async (req, res) => {
  const envs = DEV_MODE ? ['dev','staging','production'] : ['production'];
  const onDisk = listMigrationsOnDisk();           // ['000-seed-rulebook', '0001-...']
  const out = { environments: envs, head: await headInfo(), migrations: [] };
  const ledgers = {}, hashes = {};
  for (const e of envs) {
    ledgers[e] = await ledgerOf(e);                // SELECT id, applied_at ...
    hashes[e]  = await schemaHashOf(e);            // md5 of ordered DDL
  }
  for (const id of onDisk) {
    const row = { id };
    for (const e of envs) {
      const applied = ledgers[e].some(r => r.id === id);
      row[e] = applied ? (hashes[e] === out.head.hash || e !== 'dev' ? 'applied' : 'drift')
                       : 'pending';
      row[e + 'At'] = ledgers[e].find(r => r.id === id)?.applied_at || null;
    }
    out.migrations.push(row);
  }
  res.json(out);   // booleans/strings + timestamps ONLY — no connection strings
});
```

### Client — render the matrix (vanilla DOM, matches existing admin style)

```js
function renderMatrix(m) {
  const cols = ['DEV (HEAD)', ...m.environments.filter(e=>e!=='dev')
                  .map(e => e.toUpperCase())];
  const head = tr(th('Migration'), ...cols.map(c => th(c)));
  const body = m.migrations.map(row => tr(
    td(code(row.id)),
    ...m.environments.map(e => td(cell(row[e])))   // ✅ ⏳ ⬜ ⚠
  ));
  // Highlight PRODUCTION column 'pending' cells = "what a promotion will do".
  return table('matrix', head, ...body);
}
const ICON = { applied:'✅', pending:'⏳', 'not-built':'⬜', drift:'⚠', head:'✔ HEAD', src:'src' };
```

Pair with the Leopold-loop strip (a static SVG/ASCII band marking the current
position) above the matrix, and the action rail below.

---

## Floaty env switcher + dev-only endpoints

### Client — bottom-left floaty (render ONLY on localhost dev)

```js
if (location.hostname === 'localhost' && window.__DEV_MODE__) {
  const stage = window.__ACTIVE_ENV__ || 'dev';            // 'dev'|'staging'|'production'
  document.body.classList.add('stage-' + stage);           // header tint via CSS
  const fab = el('div', { class:'devops-fab stage-'+stage });
  fab.append(
    el('div', { class:'fab-stage' }, 'ENV: ' + stage.toUpperCase()),
    btn('Dev',     () => switchEnv('dev')),
    btn('Staging', () => switchEnv('staging')),
    btn('Prod',    () => switchEnv('production')),
    link('Deployment', '#admin-deployment'),
    link('Versions',   '#admin-versions'),
    btn('Analyze diff', () => post('/api/dev/devops/analyze', {a:'dev',b:stage})),
  );
  document.body.append(fab);
}
async function switchEnv(env) {
  await fetch('/api/dev/devops/active-env', { method:'POST', credentials:'include',
    headers:{'Content-Type':'application/json'}, body: JSON.stringify({ env }) });
  location.reload();   // server now serves the app against that LOCAL db
}
```

```css
/* Unmissable per-stage header tint */
.stage-dev        .topbar { box-shadow: inset 0 -3px 0 #2e9e5b; }   /* green  */
.stage-staging    .topbar { box-shadow: inset 0 -3px 0 #d9a200; }   /* amber  */
.stage-production .topbar { box-shadow: inset 0 -3px 0 #c0392b; }   /* red    */
.devops-fab { position: fixed; left: 14px; bottom: 14px; z-index: 9999;
  display:flex; gap:6px; flex-direction:column; background:#11140f; color:#d6e2c8;
  padding:10px; border-radius:10px; font:12px ui-monospace,Menlo,monospace; }
```

### Server — dev-only devops endpoints (404 when the app IS deployed prod)

```js
const devOnly = (req,res,next) => DEV_MODE ? next() : res.status(404).end();

app.post('/api/dev/devops/active-env', requireAdmin, devOnly, (req,res) => {
  const env = ['dev','staging','production'].includes(req.body?.env) ? req.body.env : 'dev';
  ACTIVE_ENV = env;                       // server re-points its pool at the LOCAL url
  reconnectPool(URL_FOR[env]);            // dev=DATABASE_URL, etc. (all localhost)
  res.json({ env });
});
app.post('/api/dev/devops/analyze',  requireAdmin, devOnly, runDiff);     // schema diff
app.post('/api/dev/devops/generate', requireAdmin, devOnly, genMigration);// → up.sql
app.post('/api/dev/devops/apply',    requireAdmin, devOnly, applyToTarget);// apply.sh
app.post('/api/dev/devops/test',     requireAdmin, devOnly, runTestsFor);  // harness
```

All targets resolved from server-side env URLs only; the browser never sees a
connection string. Promotion to `production` should require the latest `test` run
for staging to be all-green before `apply` is allowed.

---

## `scripts/devops/run-tests.sh <env>` — the green-light gate

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
case "${1:?env}" in
  dev) URL="$DEV_URL";; staging) URL="$STAGING_URL";; production) URL="$PROD_URL";;
  *) echo "env must be dev|staging|production" >&2; exit 1;; esac
assert_localhost "$URL"
# Prefer the ERB conformance suite emitted from the rulebook _meta, then UI smokes.
DATABASE_URL="$URL" npm run test:conformance
DATABASE_URL="$URL" npm run test:ui-smoke
```

Expected results that PROVE the model:
- DB-change feature: `staging`/`production` FAIL before the migration, green after.
- No-DB-change feature: green on all three with no migration.
