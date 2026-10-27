---
name: effortless-seed-authoring
description: >
  Authoring side of seeds: building, testing and publishing an add-in seed (effortless-seed.json, INTEGRATE.md,
  rulebook fragments, a server module for the generated API, web components), and the gotchas already found.
  Triggers: "make this a seed", "new seed", "assembly line", "publish the seed". Using a seed: effortless-seeds.
audience: customer
---

# Authoring seeds (the assembly line)

For *using* a seed (cloning, `$key$` answers, which add-in to reach for) see `effortless-seeds`. This is for
the person making one. The two reference seeds, both complete and tested, are the model to copy:
`effortlessapi/effortless-magic-links` (auth, SQL-heavy) and `effortlessapi/effortless-node-shopify`
(a connector, API-heavy). Start from whichever is closer; do not start from a blank directory.

## The shape of an add-in seed (kind `child`)

```
effortless.json            "ProjectTranspilers": []   (valid: the files ARE the seed)
effortless-seed.json       seed id/kind/mountPath/requires + the questions (replacements)
<name>.config.json         ONLY file with $key$ tokens; public values; server reads it, env overrides it
README.md                  what you get, the questions table, the rules it keeps
INTEGRATE.md               the wiring, for Claude: numbered steps, each ending "Works when: ..."
rulebook/*.fragment.json   the tables it adds (+ optional hooks.mjs for starter rows from flags)
scripts/merge-rulebook.mjs the SAME file in every seed: dry run unless --write, text-appends tables
sql/NN-*.sql               idempotent, run on every boot (rebuilds drop views/tables: re-apply, don't remember)
server/index.js            register<Name>(app, { pool, dir, env, ... }) for the generated API's custom.js
ui/<name>-ui.js            plain custom elements, no build, no framework; --prefix-* CSS properties
test/                      real Postgres + a stand-in for the third party; npm test
```

Rules of the line:

1. **Zero runtime dependencies**; `pg` and `express` are devDependencies for tests. The host project already has them.
2. **One registration line** in `backend/api/custom.js` (never overwritten by rebuilds). Nothing in generated files.
3. **Everything a rebuild can undo is re-applied at boot** (grants, view options, policies). The seed
   never asks someone to remember a step after `effortless build`.
4. **Secrets: environment only** (`SEED_SECRET_<key>` for persisted ones). Never in a config file, a rulebook
   table or a log. Anything secret-bearing in the database lives in its **own schema** that no request role is granted.
5. **State that is data goes in the rulebook** (tables, derived fields); **state that is a secret or a ledger
   does not** (`shopify.shops`, `auth.trusted_tenants`). Never create `app.app_users` by hand: the users table is a rulebook entity.
6. **Dev and live are one code path** with a different front door. If live cannot start it does not start;
   it never falls back to dev. Dev-only trust (keys, routes) is deleted or refused by the live boot, and
   a database that has been live refuses dev for good.
7. **Ask the person only what the seed's questions need**, then do the rest. Editing the rulebook is a
   change to the project's source of truth: dry run, say what it adds, then `--write`.
8. **Sync tables are not rulebook data.** Keep `data: []`; the generated editor's "Save changes" would
   merge database rows back into `effortless-rulebook.json`, so INTEGRATE.md must say not to use it with synced data.

## Authoring order (each step has bitten someone)

1. Write it with literal values, make it work, **then** add `effortless-seed.json` and the `$key$` tokens.
   Running the CLI inside a clone that already has the manifest substitutes the tokens away.
2. Tokens only in the one config file. The CLI replaces only declared keys, but a `$key$`-looking string
   anywhere else is a trap. Code reading that file treats ANY value still containing `$word$` (even inside a
   string like `vw_$usersTable$`) as unanswered. (Found by running a copy that was never built.)
3. Every question has a `default`, secrets included (`""`).
4. Names: repo `effortless-<thing>` under the `effortlessapi` account, seed id the same, `mountPath`
   a folder no root seed writes (roots write `docs/ postgres/ rulespeak/ explainer-dag/ xlsx/`).
5. Table/field names follow `effortless-conventions` (`Name` calculated, singular FK, `<Entity>Id` first).
   **A "reverse" relationship field on the parent is NOT how the transpiler wants it**: it generated a second
   physical FK column and a cycle. Put the FK on the child, then `COUNTIFS` aggregations / lookups on the parent.
6. Prove the names by transpiling for real: merge the fragment into any rulebook, run `rulebook-to-postgres`
   (and `rulebook-to-node-postgres-api` for the API), read `01-drop-and-create-tables.sql` /
   `03-create-views.sql` for the true table, column and view names. Do not guess snake_case.

## Verify four ways (all four found real bugs)

| Check | What it caught |
|---|---|
| `npm test` against a throwaway Postgres (`initdb` in a temp dir; short socket path, `LC_ALL=en_US.UTF-8`; `timeout` does not exist on macOS) | Logic, SQL, RLS. Keep a stand-in server for the third party that returns *real* shapes (signed tokens, paginated GraphQL, throttle errors). |
| **Mutation check**: break the one line that matters, see the right test fail, restore | A restrictive policy made permissive failed 2 tests; a webhook route left behind `express.json()` failed 4. A test that cannot fail is decoration. |
| The real generated API, built by the real transpiler, with the seed wired into `custom.js` and run | `pool.connect` inside a request, a `this.connect()` re-entry in `pg`'s `pool.query`, a middleware ordering bug: none visible with a hand-made fixture. |
| `effortless listSeeds` / `cloneSeed <account>/<repo> <relative-dir>` / `effortless build` on the published repo; a browser look at each UI | Token replacement actually touching only the config file; the page rendering with no console errors. Use a RELATIVE clone destination. |

Run **both seeds together** whenever two exist: the Shopify token being unreachable to the signed-in role
and `/api/shopify` being admin-only were only provable that way.

## Gotchas already paid for (do not rediscover)

**Postgres / RLS**
- A view runs as its OWNER and walks past row-level security on its tables. Every `vw_*` needs
  `security_invoker = true` (PG15+; newer `rulebook-to-postgres` already emits it, set it anyway, idempotently).
- Permissive policies OR together, so a project's strict policy is undone by a default allow-all. Ship the
  default only on tables with no policy of the project's own, and put the invariant ("approved, active user")
  in a **RESTRICTIVE** policy, which ANDs with everything.
- A verified email is a claim about an inbox, not an approval. Anyone can get one for their own address from
  a magic-link tenant; approval is a row, checked in the database on every request.
- **Never trust roles in token claims.** `additional_claims` are whatever the caller asked the tenant to bake in. Roles come from a table.
- `numeric` division loses digits on big numbers: use `div(a, b)`, not `trunc(a / b)`, for RSA/bignum work
  (a pure PL/pgSQL RS256 verifier is ~100 lines and needs no plpython/pgcrypto/extension).
- Superusers and table owners bypass RLS: requests must `SET LOCAL ROLE` a plain role, in the same
  transaction as the identity (`BEGIN; auth.set_jwt($token); SET LOCAL ROLE x; <query>; COMMIT`).
- Inlining a token into a simple-protocol batch is safe only after checking it is `[A-Za-z0-9_-]+(\.…){2}`.

**Express / the generated API**
- `express.json()` runs before `registerCustom` and destroys the raw bytes a webhook signature covers. Insert the
  route into the router stack after Express's own `query` and `expressInit` layers (those give `res` its
  `status()`), ahead of everything else. Do not put it at index 0: `res.status is not a function`.
- `pg`'s `Pool.query` calls `this.connect()`. If you patch `connect` to refuse unscoped use, give system
  code its own door that re-enters as a system context (`pool.__raw.query`), or it refuses itself.
- `AsyncLocalStorage` carries a per-request identity through every `await`; wrap the pool once instead of
  editing generated routes. Refuse the unscopable (`pool.connect`, callback-style queries) loudly rather than skipping RLS silently.
- Cookies ignore ports: a dev server on :41999 and another on :5173 share them. In dev, a stale or foreign
  token must start over (default dev user), not 401 the person out.
- The generated API sends `Access-Control-Allow-Origin: *`, which cannot carry credentials: keep app and API on one origin (dev proxy).
- Shopify (and similar): ask for `updated_at >= newest seen` (inclusive), so a change in the same second is never missed; dedupe webhooks on the delivery id;
  answer 200 before doing the work; ignore other shops' deliveries with a 200 (a non-200 makes them retry forever); keep personal data out of the ledger.

## Publishing

1. Public repo under the `effortlessapi` account, default branch has `effortless.json` at the root:
   `gh repo create EffortlessAPI/<name> --public --source . --push`. That alone makes `effortless listSeeds`
   list it and `cloneSeed effortlessapi/<name> <dir>` work.
2. **The catalog (the website's "Add to project" list)** reads the repo, never typed by hand: a HOUSE seed
   lives in `www-rulebook-server`'s rulebook (`node scripts/register-seed.js <repoUrl>`, then `effortless build`)
   and in each database through the admin portal's Seeds workspace or `POST /api/admin/seeds/register`.
   Registering on PRODUCTION is a change to a live system: get an explicit yes for that exact action first.
   `Status` starts `proposed`/`building`; only `available` seeds are offered.
3. Prices are a `Products` row pointing at the seed, never a column on it. That is the owner's call.
4. Update this skill with what the next seed taught you, then `bash lint-skills.sh`, `bash install.sh --yes`, and push `effortless-skills`.
