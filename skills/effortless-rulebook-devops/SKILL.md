---
name: effortless-rulebook-devops
description: >
  Use to stand up a complete **3-layer localhost dev-ops model** (dev → staging →
  production, ALL on localhost for now) for any Effortless Rulebook (ERB) project,
  with a Leopold-loop + deployment **visualizer** admin page, an ERBVersions
  version log with generated migrations, and a floaty bottom-left environment
  switcher that connects the running localhost app to dev / staging / production
  without redeploying. Triggers: "set up rulebook dev-ops", "three-database
  localhost model", "simulate dev/staging/prod locally", "Leopold loop
  visualizer", "deployment page for the rulebook", "version + migration the
  rulebook", "environment switcher floaty", "make a 000-seed-rulebook migration".

  This skill is HEAVY and meant to be invoked ONCE per project to scaffold the
  whole model; afterwards the per-project admin page + skills drive day-to-day use.

  **Scope (load gate):** Effortless projects only — project root must contain
  `effortless.json` AND a CLAUDE.md identifying the project as ERB methodology.
  Localhost-only: this skill never creates, points at, or migrates a remote
  database. "Production" here is a LOCAL database that stands in for real prod
  until you choose to move it. Do NOT load otherwise.
audience: customer
---

# Effortless Rulebook Dev-Ops — the 3-layer localhost model

This skill makes a single ERB project rehearse its **entire deploy lifecycle on
localhost**, so the Leopold loop, versioning, migrations, and the dev→staging→prod
promotion are all real, visible, and testable before anything touches a remote.

> **The whole point:** you should be able to develop a feature on `dev`, watch it
> work (or *predictably fail*) against `staging` and `production` **without
> redeploying the app**, generate and push a migration to `staging`, confirm it
> goes green there, and only then push the same migration to `production`. All
> three databases are local. Moving `production` to a real remote is a *later*,
> separate decision — this skill deliberately does not do it.

---

## 0. The model (read this first — it is the spine of everything)

```
   ┌─────────────────────── R U L E B O O K  (HEAD, in git) ───────────────────────┐
   │   effortless-rulebook.json   +   admin editor (no-code edits, MOCK data)       │
   └───────────────┬────────────────────────────────────────────────────────────────┘
                   │  effortless build → dev-postgres-bootstrap/init-db.sh
                   │  (LOCALHOST ONLY · DROPS + RESEEDS · the "Leopold loop")
                   ▼
            ┌────────────┐      generate migration       ┌────────────┐   same migration   ┌──────────────┐
            │    DEV      │  (diff dev-init-db ↔ staging) │  STAGING   │ ─────────────────► │  PRODUCTION   │
            │  <db>       │ ────────────────────────────► │ <db>_staging│   (promote)        │ <db>_production│
            │  = HEAD     │                               │ via migs   │                    │   via migs    │
            └────────────┘                                └────────────┘                    └──────────────┘
            reborn by init-db                              never dropped                      never dropped
            (build = Leopold loop)                         moves ONLY by migration            moves ONLY by migration
```

### The invariants (these never bend — they are why the model is trustworthy)
1. **`init-db.sh` only ever touches `dev`, and only on localhost.** It DROPS and
   reseeds. It must hard-refuse any non-localhost host AND any DB name that is not
   the dev DB. Staging and production are **never** init-db'd — not even locally.
2. **`staging` and `production` move ONLY by `migrations/apply.sh`** (ledger-tracked
   in `public.schema_migrations`, run-once-each, applied in lexical order). This is
   identical whether the target is local-staging, local-production, or — someday —
   a real remote. Same runner, same migration files.
3. **The seed migration `000-seed-rulebook.sql` is the full init-db schema stack.**
   An empty DB + `000-seed` + every later migration = the current dev schema. This
   is what lets staging/production be *built from nothing* by replaying migrations.
4. **A "version" is an ERBVersions row** (commit message + the generated migration
   it produced). Cutting a version is how the loop's current state becomes a
   promotable, named artifact.
5. **Save semantics differ by the active DB** (this is the write-side mirror of
   invariant 1):
   - Pointed at **dev** → **"Save to rulebook"**: dual-write the live dev DB **and**
     reverse-sync `effortless-rulebook.json` so the next build preserves the edit.
   - Pointed at **staging/production** → **"Save to <env> DB"**: a direct DB write.
     There is no design-time rulebook here and the schema is never dropped, so the
     write persists permanently (until a migration/restore changes it).

### The two behaviors that PROVE the model (demand these in testing)
- **No-DB-change feature** → works identically on dev, staging, AND production with
  no redeploy, because the schema backend is unchanged (invariant 2). The floaty
  switcher flips the app between all three and the feature is green everywhere.
- **DB-change feature** → works on dev (init-db rebuilt it) but **fails in a
  predictable, legible way** on staging/production until a migration is generated,
  pushed to staging (now green on staging, still failing on prod), and finally
  pushed to production. The deployment page must make this gap *visible*.

---

## 1. When to run this / preconditions

Run once, early, on an ERB+Postgres project. Confirm before doing heavy work:

- Project has `effortless.json` + an ERB CLAUDE.md + `effortless-rulebook.json`.
- `effortless build` works and produces `dev-postgres-bootstrap/00–05*.sql` +
  `init-db.sh`. (If not set up yet, use **effortless-setup-postgres** first.)
- Local Postgres is reachable; you know the dev `DATABASE_URL`.
- This is **not** a project that already has a remote prod you might clobber —
  remember, this skill is localhost-only and "production" is a *local* DB.

Then walk the phases below **in order**. Each phase is a checkpoint: show the user
what you're about to do, do it, confirm it worked, move on.

---

## 2. Phase A — Admin editor for the rulebook (detect, else offer to scaffold)

**A1. If the project already has an admin editor for the rulebook, USE IT.**
Look for any of: an `app/admin/` UI, a `/api/admin/:entity` surface, a routing/menu
editor, or a reverse-sync-to-rulebook path (`scripts/sync-*-to-rulebook*`,
`reverseSyncEntity`). If found, you will add the deployment page + switcher *into*
that existing admin (Phase D/F) rather than building a new shell.

**A2. If there is NO admin editor, OFFER to create a lightweight one.**
A super-lightweight **Express + Vite** editor over **every element of the rulebook**
(tables, fields, mock rows, routing), styled to make it unmistakable that **this is
MOCK DATA** (a persistent banner: *"Rulebook mock data — not real records"*).
- Express serves `/api/admin/:entity` (list/save) over the `vw_*` views + base
  tables, plus the reverse-sync-to-rulebook write (Save-to-rulebook).
- Vite renders a generic grid per rulebook table, driven by the schema in
  `effortless-rulebook.json` — no hand-written form per table.
- Keep it generic and rulebook-driven; do not hardcode the project's tables.
- See `reference/templates.md` → **"Lightweight rulebook admin (Express+Vite)"**.

Do not build A2 silently — confirm scope with the user first; it is the biggest
optional chunk.

---

## 3. Phase B — Create the three LOCAL databases

Create, on localhost only:

| Role | DB name (convention) | First filled by | Then advanced by |
|---|---|---|---|
| dev | `<db>` (e.g. `pm_assessment`) | `init-db.sh` (rulebook HEAD) | every `effortless build` |
| staging | `<db>_staging` | `000-seed-rulebook` migration | `migrations/apply.sh` |
| production | `<db>_production` | `000-seed-rulebook` migration | `migrations/apply.sh` |

- Use `scripts/devops/00-create-local-envs.sh` (template in `reference/templates.md`).
  It `assert_localhost`s, creates the two extra DBs if absent, and **does not** run
  init-db against them.
- Register all three as **DB targets** the running app can be pointed at (the
  switcher in Phase F): `DATABASE_URL` (dev), `STAGING_DATABASE_URL`,
  `PRODUCTION_DATABASE_URL` — all `localhost`, none committed with secrets.
- **Ideal-world note (point 9):** in real operation `staging` should be a *recent
  restore of production* so the migration test is as realistic as possible. Locally,
  emulate that with a `staging := clone(production)` action before generating a
  migration (template: `scripts/devops/restore-staging-from-production.sh`).

---

## 4. Phase C — The seed migration (`000-seed-rulebook`)

`migrations/000-seed-rulebook/up.sql` = **the entire init-db schema stack**, written
idempotently so it can build an empty DB to the current dev schema.

- Generate it from the freshly-built `dev-postgres-bootstrap/00–05*.sql` (schema
  only — tables, views, functions, RLS; **no** mock data rows, OR clearly-marked
  seed rows only). Make every statement idempotent
  (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE`, guarded `ENABLE RLS`).
- Apply it to **staging** and **production**:
  `bash migrations/apply.sh "$STAGING_DATABASE_URL"` and likewise for production.
  Both are now at the baseline and in sync with dev.
- This migration is **special**: it is *regenerated* whenever you "rebaseline"
  (after a production promotion, the post-migration state becomes the new seed).
  Normal additive migrations after it are immutable.

**Verify the model end-to-end now:** drop+recreate an empty scratch DB, run
`apply.sh` against it, and confirm its schema equals dev's. If that passes, the
"build staging/prod from nothing by replaying migrations" guarantee holds.

---

## 5. Phase D — The deployment page = a Leopold-loop + migration-matrix visualizer

Add (or extend) an admin **Deployment** page that visualizes the *whole* cycle
**right out of the gate**. Two stacked views:

### D1. The Leopold loop (top) — the cycle itself, animated/annotated
```
   rulebook ──build──► DEV ──generate diff──► migration ──apply──► STAGING ──promote──► PRODUCTION
       ▲                                                                                     │
       └──────────────── reverse-sync (Save-to-rulebook) ◄───── edits in admin ◄────────────┘
```
Label the current position in the loop (e.g. "DEV is ahead — generate a migration").

### D2. The migration × environment matrix (the deployment state)
Rows = migrations oldest→newest. Columns = **Dev (HEAD) · Staging · Production**.
Cells: `✅ applied · ⏳ pending · ⬜ not built · ⚠ drift`. The **pending cells in
the Production column are literally "what a production promotion will do."**

```
MIGRATIONS ──────────────   DEV(HEAD)  STAGING   PRODUCTION
000-seed-rulebook            src        ✅        ✅
0001-<change> (v2026.06.14)  ✔ HEAD     ✅        ⏳ PENDING   ◄─ promote will run this
0002-<change> (draft)        ✔ HEAD     ⏳        ⏳
```
- Read each env's ledger from its own `schema_migrations` (all local). Never send a
  connection string to the browser — only applied/pending booleans + timestamps.
- Because of drift-as-first-class (ERB), back the "✔ HEAD" / `⚠ drift` signal with a
  cheap **schema-hash compare** per env, not just the ledger — the ledger says "the
  file ran", the hash says "the schema actually matches". Prefer the hash where they
  disagree.
- Endpoint + render skeleton: `reference/templates.md` → **"Deployment matrix endpoint + page"**.

The page also surfaces the **ERBVersions** log (Phase E) and the **action rail**
(generate migration · apply to staging · promote to production · rebaseline · run
tests), each backed by a `scripts/devops/*` call. Promotion to *production* — even
the local one — is **not** a careless one-click: it prints the exact command + a
checklist, so the muscle memory matches the day you move prod to a real remote.

---

## 6. Phase E — Versions (ERBVersions) + generated migrations

"Once the loop is stable, create a new version."

- **ERBVersions** is a dev-ops tracking table (one row per cut version):
  `erb_version_id, version, commit_message, migration_id, rulebook_build,
  created_at, created_by, dev_schema_hash`. DDL in `reference/templates.md`.
  Keep it in the migration-tracked DBs (so staging/prod carry their own history),
  or in a dedicated devops schema — pick one and be consistent.
- **Cut a version** (admin action → `scripts/devops/cut-version.sh`):
  1. `effortless build` (ensure dev = HEAD; Leopold loop).
  2. Generate the migration by diffing **dev's init-db schema** ↔ **staging's current
     state** → `migrations/NNNN-<slug>/up.sql` (additive in the nominal case;
     review it). This is point 8 — "derive a new migration based on the latest
     init-db.sh db (dev) and the current staging state."
  3. Insert an ERBVersions row with the commit message + the new `migration_id`.
- Versions are the unit you promote: apply `NNNN` to staging, test, then to production.

---

## 7. Phase F — The floaty environment switcher (localhost-only, bottom-left)

A small floating control, **only rendered on localhost dev builds**, bottom-left,
that pops up to:

- **Connect the running app to dev / staging / production** (flip the active DB the
  server uses; reload). Because all three are local and the API is the same, this is
  how you prove "works on all three without redeploying" vs "fails predictably until
  migrated" (points 11–14).
- **Style the header per stage** so the current environment is *unmissable*
  (e.g. dev = green, staging = amber, production = red banner across the top).
- **Deep-link** to the relevant admin dev-ops sections (Deployment page, Versions,
  test harness).
- **Analyze DB differences** (dev↔staging, staging↔production), **generate diffs**,
  **apply diffs** — each backed by a `scripts/devops/*` endpoint that is **dev-only
  (404 when the app itself is the deployed prod)**.

Guard everything: the switcher and its `/api/dev/*` endpoints must be inert/absent
unless the running copy is the localhost dev build. Template + guards in
`reference/templates.md` → **"Floaty env switcher + dev-only endpoints"**.

---

## 8. Phase G — Test harness integration (the green-light gate)

Wire the project's conformance/UI tests so they can run **against any of the three
DBs from the same panel**, and make test status the gate for promotion (points
13–15):

- Run tests against **dev** (should be green — it's HEAD).
- Run the same suite against **staging** *before* a migration → for a DB-change
  feature it should **fail predictably**; *after* applying the migration → green.
- Against **production** → still failing until the migration is promoted; green only
  after. **Only an all-green staging run unlocks the "promote to production" action**
  (plus, for real prod later, a CI/CD push).
- Surface the latest run per env on the Deployment page (a small ✅/❌ per column),
  so the matrix doubles as a health monitor.

ERB already emits a conformance suite from the rulebook `_meta`; prefer that as the
backbone and add UI smoke tests on top.

---

## 9. What this skill creates (artifact map)

```
scripts/devops/
  _lib.sh                         # assert_localhost, PG_BIN resolve, env URLs
  00-create-local-envs.sh         # create <db>_staging, <db>_production (local)
  restore-staging-from-production.sh   # staging := clone(production)  [ideal-world]
  cut-version.sh                  # build → generate migration → ERBVersions row
  generate-diff.sh                # dev init-db ↔ staging  → migrations/NNNN/up.sql
  apply.sh-wrapper                # thin wrapper over migrations/apply.sh per target
  analyze-diff.sh                 # schema diff/hash between any two targets
  run-tests.sh <env>              # conformance + UI tests against one target
migrations/
  000-seed-rulebook/up.sql        # FULL init-db schema stack (idempotent)
  NNNN-<slug>/up.sql              # generated additive migrations
  apply.sh                        # the one true runner (ledger-tracked)
app/admin/ (new or extended)
  Deployment page                 # Leopold loop + migration×env matrix + action rail
  Versions page                   # ERBVersions log
  floaty env switcher             # bottom-left, localhost-only
server (Express)
  /api/admin/deployment/matrix    # cross-env ledger + schema-hash (booleans only)
  /api/dev/devops/*               # dev-only actions (switch DB, diff, apply, test)
```

(ERBVersions + `schema_migrations` live in the DBs, not the file tree.)

---

## 10. Guardrails (do not break — these keep "production" safe even while local)

- **Localhost only, always.** Every script `assert_localhost`s. `init-db.sh` refuses
  non-localhost **and** any DB name other than the dev DB. The switcher + `/api/dev/*`
  are inert unless the running copy is the localhost dev build.
- **init-db touches ONLY dev.** Staging/production move ONLY through `apply.sh`.
- **Never send a connection string to the browser.** The matrix ships booleans and
  timestamps; switching DBs happens server-side.
- **Promotion is deliberate**, even locally: production actions print command +
  checklist, and require an all-green staging test run. Build the muscle memory now.
- **Save label tracks the active DB** (dev → "Save to rulebook"; staging/prod →
  "Save to <env> DB"). Never promise "to rulebook" when the reverse-sync won't run.
- **Don't hand-edit generated `dev-postgres-bootstrap/00–05*.sql`** — the rulebook is
  HEAD; edit `effortless-rulebook.json` and rebuild.
- When you eventually **move production to a real remote**, nothing about the loop
  changes except `PRODUCTION_DATABASE_URL` and the gating around it — that is the
  payoff of rehearsing the whole thing on localhost first.

---

## 11. Relationship to other skills

- **effortless-leopold-loop** — the build→consume cycle this page visualizes.
- **effortless-setup-postgres** — run first if the project has no dev DB yet.
- **staging-cutover** (project-local, in ai-pm-assessment) — the hand-rolled
  predecessor of this skill, scoped to one project; this skill generalizes it.
- **effortless-sql / effortless-diagnostics** — view-reads, drift, and DAG health
  that back the matrix's `⚠ drift` signal.

See `reference/templates.md` for copy-pasteable skeletons of every script, endpoint,
and UI piece referenced above. Treat them as starting points to refine per project.
