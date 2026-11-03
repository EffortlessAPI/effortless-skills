# Magic-links refactor — skill-set updates (plan 03)

This document is the **single source of truth** for the changes that
the magic-links refactor requires across the effortless-claude skill
set. Each skill SKILL.md file references this document; the cold
reviewer should be able to verify acceptance by checking that:

1. This document exists and contains the expected sections.
2. Each affected skill's SKILL.md links to it (or quotes the relevant
   block verbatim).

Source of truth for the cross-service plan:
`api.effortlessapi.com/magic-links-refactor/03-effortless-claude-plan.md`

---

## §1 Canonical install step (effortless-setup-postgres)

The first-time bootstrap of a postgres project MUST install the magic-
links auth contract. Order of operations:

1. After `effortless build` succeeds the first time, fetch the install
   script:

   ```
   curl -fSL https://magiclink.effortlessapi.com/install-magic-links/v1.sql \
     -o postgres/install-magic-links.sql
   ```

2. Either mint a tenant via `POST /api/tenants` (passing
   `project_name` = the project name from `effortless.json` and
   `display_name = "{project_name} (localhost dev)"`) or prompt the
   user for an existing tenant id.

3. For per-tenant installation that includes the registration stanza:

   ```
   curl -fSL https://magiclink.effortlessapi.com/api/tenants/{id}/install.sql \
     -o postgres/install-magic-links.sql
   ```

4. Run `psql … -f postgres/install-magic-links.sql` against localhost.

5. The transpiler-generated `init-db.sh` already re-runs this script
   at the start of every build. It is idempotent.

This step is **mandatory** for every postgres bootstrap, whether
local or against bases.

## §2 effortless-magic-links pointer-not-inline

`skills/effortless-magic-links/REFERENCE.md` should NOT contain an
inline `CREATE SCHEMA IF NOT EXISTS auth …` block. Replace any such
block with:

> Fetch the script from
> `https://magiclink.effortlessapi.com/install-magic-links/v1.sql`.
> The contract surface is `auth.set_jwt(token)`, `app.jwt_email()`,
> `app.jwt_tenant_id()`, `app.jwt_claims()`, `app.has_role(role)`.
> Full details in `magiclink.effortlessapi.com/AUTH_API_REFERENCE.md`.

DO-NOT section to add:

> **Never put `tenant_id` or `public_key_pem` in the rulebook
> (Airtable). Never create `ERBmagiclinks` or
> `MagicLinkIntegration` tables.** The auth schema is the only source
> of truth. If you find such a table in an existing project, that's
> the v1 anti-pattern; offer migration to `auth.trusted_tenants`.

## §3 RLS template idiom

Every RLS skill snippet (in `effortless-magic-links`,
`effortless-sql`, `effortless-bases`) must use the same idiom:

```sql
CREATE POLICY clients_owner_select ON clients
  FOR SELECT TO magiclink_consumer
  USING (owned_by_email_address = app.jwt_email());

CREATE POLICY admin_clients_select ON clients
  FOR SELECT TO magiclink_consumer
  USING (app.has_role('admin'));
```

Forbidden:

- `current_setting('app.jwt_email', true)` directly — use the helper.
- `current_setting('request.jwt.claim.email', true)` directly.
- `current_user`, `session_user`, env vars for identity.
- Any policy that does not go through `app.jwt_*()`.

If a skill file mentions any of the forbidden patterns, it MUST
clearly mark them as anti-patterns (so the lint pass at §8 doesn't
flag a documentation example as a real use).

## §4 Hard gate for changes to bases (effortless-bases)

User's framing — verbatim opening of `effortless-bases/SKILL.md`:

> **Changes to ANY BASES BASE NEEDS TO BE REALLY EXPLICITLY GATED!!
> DO NOT JUST GO MAKE CHANGES WITHOUT CONFIRMING EXACTLY WHAT CHANGES
> ARE GOING TO BE MADE.**

The Stage-gating block:

> **Before making ANY change to a `bases.effortlessapi.com` base,
> Claude MUST:**
>
> 1. Fetch the base's `Stage` field via `GET /api/bases/{id}`.
> 2. If `Stage = prod`:
>    - Refuse to run any schema-mutating SQL or any bases API call
>      without first stating the **exact** changes (DDL diff, data
>      diff, RLS diff) and getting explicit user confirmation.
>    - Always run the migration against a `dev` or `staging` base
>      first; show the result; then ask again before applying to prod.
>    - Use `confirm-prod-change: <summary>` header on the bases API
>      call (per plan 02 §5).
> 3. If `Stage = staging`:
>    - State the changes; one confirmation; then proceed.
> 4. If `Stage = dev`:
>    - Proceed normally, but always summarize what was changed at the
>      end of the turn.
>
> **Never** run `effortless build` against a bases base. Never run
> `init-db.sh` against a bases base. Never `DROP` anything in a bases
> base without an explicit `--i-mean-it` user confirmation.
> Migrations only, via `postgres/apply-migration.sh` or the
> equivalent.

## §5 New build modes (effortless-pipeline)

`effortless-pipeline/SKILL.md` documents the new
`rulebook-to-postgres` modes (plan 04):

- **Default `check-don't-drop`** (a.k.a. `mode=check-add` in the
  transpiler params): safe to run repeatedly; preserves data; adds
  missing tables/columns; runs the `NN[b]?-*.sql` files on disk in lex
  order; re-runs `install-magic-links.sql`. The lettered
  `NNb-customize-*.sql` files are legacy and reach local Dev only (a
  stage or base never gets them); customizations are `ERBCustomizations`
  rows (see `effortless-sql`). **NOTE:** the
  full check-add SQL emission is tracked as Phase 2.5 in
  `magic-links-refactor/MASTER-PLAN.md`. The init-db.sh changes
  (glob discovery, `.disabled` skip, bases-URL refusal,
  `.applied-manifest.json`) are live now.

- **Nuclear (`drop-all=true`)**: localhost only; drops everything
  in `public` (auth schema untouched); use when iterating on a
  clean rulebook. Refused by the transpiler when `stage` is
  `staging` or `prod`.

- **`.sql.disabled` skip** — rename `04b-customize-policies.sql`
  → `04b-customize-policies.sql.disabled` to opt out for one build.
  Affects local Dev only: the on-disk `04b-customize-policies.sql` is a
  legacy file that never reaches a stage or a bases base. A row named
  `04b-customize-policies.sql` still rides `update-effortless-schema.sql`;
  renaming the file does not opt it out.

Rule: Claude must always run with the safe default
(`check-don't-drop`) against any base it didn't create in the same
conversation. Nuclear mode is opt-in via the user typing it
explicitly.

## §6 Anti-pattern flags (effortless-conventions)

`effortless-conventions/SKILL.md` adds:

> **Anti-pattern: `MagicLinkIntegration` / `ERBmagiclinks` rulebook
> tables.** Auth state (`tenant_id`, `public_key_pem`, JWT helpers)
> does not belong in the rulebook. Don't add an `ERBmagiclinks`,
> `MagicLinkIntegration`, or any `Auth_*` / `App_Jwt_*` table to
> Airtable, ever. Auth lives in `install-magic-links.sql` and
> `auth.trusted_tenants`.

> **Anti-pattern: v1 GUC-cache.** Raw
> `set_config('app.jwt_email', …)` from Node middleware + RLS
> policies reading `current_setting('app.jwt_email', true)` directly,
> with no `auth.set_jwt(token)` in transaction. When you see this
> shape, offer the v2 migration. The v2 shape is `BEGIN; SELECT
> auth.set_jwt($1); … COMMIT;` and policies use `app.jwt_email()`.

If a skill detects either pattern during a project audit, it should
flag and offer migration.

## §7 Routing updates (effortless-orchestrator)

`effortless-orchestrator/SKILL.md` adds:

> **Routing for magic-links work**:
>
> - any task that touches `bases.effortlessapi.com` → route to
>   `effortless-bases` (read its hard-gate block before doing
>   anything).
> - any auth / RLS / tenant / `auth.trusted_tenants` /
>   `app.jwt_email` / JWT-verification task → route to
>   `effortless-magic-links`.
> - any postgres-bootstrap task (`-init-db.sh`, install scripts,
>   `effortless build`, schema changes via the rulebook) → route to
>   `effortless-setup-postgres` AND make sure the canonical
>   install step (§1 above) is part of the bootstrap.

## §8 Lint rule

`lint-skills.sh` (in this repo root) checks for skills that mention
`current_setting('app.jwt_*')` or `current_setting('request.jwt.…')`
outside an explicit anti-pattern callout.

The lint rule:

```
grep -rE "current_setting\\('(app\\.jwt|request\\.jwt)" skills/ \\
  | grep -v "anti-pattern" | grep -v "DO-NOT" \\
  && echo "FAIL: forbidden patterns outside anti-pattern callouts" \\
  || echo "OK"
```

Skill authors who NEED to mention the forbidden patterns must put
them in a section with the heading "Anti-pattern" or "DO-NOT".

## §9 Bases-targeting bootstrap generates 3 artifacts

When `effortless-setup-postgres` (or `effortless-init` /
`effortless-bases`) detects that the project will talk to a bases
base — presence of `BASES_DATABASE_URL` in `.env.example`, or a
`Stage` value on a known base, or the user explicitly says "this is
a bases project" — Claude MUST generate **three artifacts** before
doing anything else:

1. Append the canonical `## Bases is migration-only — never rebuilt
   from scratch` block to the project's `CLAUDE.md`. The verbatim
   text lives in this repo's `effortless-bases/SKILL.md`. Source of
   truth: `bases.effortlessapi.com/BASES_MIGRATION_GUIDE.md` (plan 02
   §8).

2. Drop `postgres/apply-migration.sh` into the project, fetched from
   the bases repo template (raw URL or local checkout). Bug fixes in
   the wrapper propagate via skill update, not per-project edits.

3. Create `postgres/migrations/.applied.log` (empty) and
   `postgres/migrations/.gitkeep`.

Subsequent runs check that all three are present and re-fetch the
template if it has drifted from the canonical version.

## §10 Runtime guard against `psql` against bases

Skills MUST never suggest `psql $BASES_DATABASE_URL -f …` directly —
only `postgres/apply-migration.sh <file>`. If the user types the raw
`psql` command against bases, refuse and explain why (point at this
section + the BASES_MIGRATION_GUIDE.md).

This is enforced as a settings.json hook in the project template (see
`magic-links-refactor/03-effortless-claude-plan.md` work item #4 +
§4 + #10 + the "open question" about per-project hooks).

## §11 RLS policy lifecycle against bases

Policies are the exception to §4 + §9's migration rule: an RLS policy change destined for a
bases base starts in the rulebook. Policies are rebuilt by the
derived/RBAC layer; never hand-migrate a policy. The first apply is
the generated tables and data plus `update-effortless-schema.sql`
(which carries the function and view override rows and the `02b`-`05b`
rows; see `effortless-sql` for what it does not carry). Skills must NOT edit
`04b-customize-policies.sql` (legacy, local Dev only): its SQL never
reaches bases. See `effortless-sql` and `effortless-bases`.

## §12 Capture the magic-links tenant API key on bootstrap

Plan 01 §4 ships an api-key that gates the **custom-claims mint
path** (`verify-code` with an optional `claims: {...}` body). When
`effortless-setup-postgres` mints a new tenant **and the user opts
in to custom claims**, Claude:

1. Captures the plaintext key from the tenant-create response.
2. Verifies `server/.env` is in `.gitignore`, then writes
   `MAGICLINK_TENANT_API_KEY=<plaintext>` to `server/.env`.
3. Adds a placeholder line to `server/.env.example`:
   `MAGICLINK_TENANT_API_KEY=replace-me-32-hex-chars`.
4. Updates the server's magiclink proxy to attach
   `X-Tenant-Api-Key: ${process.env.MAGICLINK_TENANT_API_KEY}` only
   on `verify-code` calls that include a `claims` body. Other
   proxied calls do not get the header.

If the tenant did not opt in to custom claims, none of the above
runs — there is no key, no env var, no header.

If the operator loses the key, they re-fetch via plan 01's
`GET /api/tenants/{id}` under admin auth. Rotation, "never echo in
chat", "never commit" disciplines are tracked in
`magic-links-refactor/07-critical-next-steps.md`.

---

## §13 LOCALHOST MODE — opt-in via env vars

> **READ THIS FIRST when bootstrapping any project.** It changes
> nearly everything below.

The skills above default to **production** URLs:

```
MAGICLINK_BASE_URL=https://magiclink.effortlessapi.com   # default
BASES_BASE_URL=https://bases.effortlessapi.com           # default
```

When the operator is running the **local dev stack**
(magic-links-refactor/test-env/scripts/dev-stack-up.sh — see
api.effortlessapi.com), Claude MUST detect localhost mode and
adjust behavior accordingly. Detection rule:

> Localhost mode is on when `MAGICLINK_BASE_URL` is set to a
> `http://localhost:*` URL **OR** when the operator says "use the
> local dev stack" / "localhost magic-links" / similar in the
> prompt.

When localhost mode is on:

| Step | Production behavior | Localhost behavior |
|---|---|---|
| Mint tenant | `POST https://magiclink.effortlessapi.com/api/tenants` (requires self-auth Bearer JWT) | `POST $MAGICLINK_BASE_URL/api/tenants` against the local server. Self-auth JWT is in `magic-links-refactor/test-env/dev/.env` as `OWNER_JWT` — source it and use it. |
| Fetch install.sql | `curl https://magiclink.effortlessapi.com/api/tenants/{id}/install.sql` | `curl $MAGICLINK_BASE_URL/api/tenants/{id}/install.sql` |
| Send magic-link code | Real email-receipt loop required. | **Skip the email loop.** The local server's `NODE_ENV=test` accepts the literal debug code `424242` in `verify-code` requests. Document this in the project's README so the operator can demo without an email round-trip. |
| Register the project as a base | `POST https://bases.effortlessapi.com/...` (requires real bases auth) | `POST $BASES_BASE_URL/...` against the local bases server (which is itself a base on the local self-DB). |
| What goes in `server/.env` of the new project | `MAGICLINK_BASE_URL=https://magiclink.effortlessapi.com` | `MAGICLINK_BASE_URL=http://localhost:4787` |
| What goes in `server/.env.example` | `MAGICLINK_BASE_URL=https://magiclink.effortlessapi.com` | Same example URL — the localhost is for the operator's local dev only; `.env.example` should still show the production URL. |
| Bases prod-stage gate | `confirm-prod-change: <summary>` header required. | Local bases lets every base default to `Stage=dev` so the gate is auto-permissive. The skill must still NOT default a base to `Stage=prod` in localhost mode. |

**Operator quick-ref** for what's where in localhost mode:

```
magiclink server      http://localhost:4787
bases server          http://localhost:4788
unified dashboard     http://localhost:4789
local Postgres        postgres://localhost:5432/<dbname>
.env file with all    magic-links-refactor/test-env/dev/.env
the URLs + JWTs       (source it before any curl recipe)
```

**The 424242 dev code is load-bearing for demos.** When the skill
walks the operator through "now check your inbox" in production,
in localhost mode it walks them through "the magiclink server is in
debug mode; use code `424242`" instead. No SMTP needed; no real
email account needed. This is the entire point — the demo is
self-contained.

**One last gate:** in localhost mode the skill MUST verify the
local stack is actually up before proceeding. Quick check:

```bash
curl -fsS http://localhost:4787/install-magic-links/v1.sql >/dev/null \
  && echo "magiclink up" || echo "magiclink DOWN — run dev-stack-up.sh"
curl -fsS http://localhost:4788/health >/dev/null \
  && echo "bases up" || echo "bases DOWN — run dev-stack-up.sh"
```

If either is down, point the operator at:

```
bash magic-links-refactor/test-env/scripts/dev-stack-up.sh
```

---

## How a cold reviewer verifies this

1. This file exists at `effortless-claude/MAGIC_LINKS_REFACTOR.md`.
2. Each of the affected SKILL.md files contains a pointer line like
   `> See [MAGIC_LINKS_REFACTOR.md](../../MAGIC_LINKS_REFACTOR.md)
   §N for the v0.2 magic-links contract.`
3. The lint script `lint-skills.sh` exits 0 (no forbidden patterns
   outside anti-pattern callouts).
4. **Localhost mode** is documented at §13 with a behavior table,
   the 424242 dev-code recipe, and the up-check commands.
