---
name: effortless-demo-app
description: >
  Use when the user wants to spin up a complete Effortless POC demo app from
  a one- or two-sentence domain description — no Airtable, no Shadle steps,
  just the fastest path from "make this an effortless demo for X" to a
  running Express + Vite SPA backed by a Postgres-generated rulebook with a
  multi-hop calculated-field DAG that the UI exercises end-to-end.

  Triggers: "make this an effortless demo for …", "build an effortless POC
  for …", "spin up a demo app for …", "effortless demo app", "quick
  effortless demo of …".

  **Scope (load gate):** Loads only on explicit user request for a demo app.
  Does NOT require a marked Effortless project — this skill *creates* one.
audience: customer
---

# Effortless Demo App — one-line description to running POC

The fastest possible path from a 1-2 sentence domain description to a fully
functional demo app: rulebook-first Postgres, Express + Vite SPA, dev login
for 2-3 roles, multi-hop calculated-field DAG, mock data that "flexes"
every inference, and deep routing so F5 always works.

For **demos and POCs**, not production. No Airtable, no magic-links, no
Shadle steps, no migration tooling.

## Load these skills first

Before doing any work, load (in this order):

1. `effortless-orchestrator` — mental model + token discipline
2. `effortless-setup-postgres` — postgres pipeline setup (skip the
   Airtable-pull steps; this is Path B)
3. `effortless-conventions` — naming rules, DAG structure, PascalCase
   tables, Name field formula, why no M:N
4. `effortless-schema` — JSON shape of `effortless-rulebook.json`
5. `effortless-pipeline` — `effortless.json`, transpiler catalog, build flow
6. `effortless-sql` — read views, write base tables, calculated functions
7. `effortless-leopold-loop` — the edit-rulebook → build → consume loop

Skip: `effortless-airtable*`, `effortless-bootstrap` (Shadle steps),
`effortless-magic-links`, `effortless-bases`.

## Invariants (do these, don't ask about them)

1. Postgres + rulebook-first (Path B). SSoT is
   `effortless-rulebook/effortless-rulebook.json`.
2. Stack: Express (`server/`) + Vite + React + React Router (`web/`).
3. Dev login: `X-User-Email` stub auth, login page reads `/api/dev-users`
   and lets the user click any seeded identity. 2-3 roles.
4. Every page has its own route — F5 always lands the user on the same
   page. Role-guarded routes use `<Navigate replace />`, never
   conditional rendering.
5. The first role listed is the **fully-wired primary** role. Other
   roles get a labeled placeholder page that describes what they'd see.
6. README first, with a short narrative + a "try this" walkthrough.
7. The rulebook MUST include 3–5 entities, 1–2 inferences per entity
   minimum, and at least one **2–3 hop inference chain** (raw →
   1st-order calc → 2nd-order calc → optional 3rd-order).
8. The raw fields that feed the DAG must be editable in the UI, so the
   user can watch cascading recomputation live.
9. Mock data flexes every inference. For every boolean/threshold rule
   (e.g. `IsFoo = TotalBar > 100`), seed at least one row on each side
   of the threshold. For every enum-producing rule, seed one row per
   enum value.

## If the user didn't give you a domain

Offer to pick. Use `AskUserQuestion` with four options — three concrete
one-sentence POC suggestions plus a "type your own" option. The
suggestions should be small, distinct domains with obvious multi-hop
inference chains. Vary them across runs; examples of the *shape* of a
good suggestion (don't reuse these verbatim):

- "A small auto-body shop tracking parts and basic inventory transactions."
- "A neighborhood library tracking books, borrowers, and overdue fees."
- "A community garden tracking plots, plantings, and harvest yields."

Anything where you can sketch a 2–3 hop DAG in your head works.

## Questions to ask

There is **no cap**. Ask as many questions as you genuinely need to make
the rulebook concrete. Ask in a single `AskUserQuestion` batch up front
when possible; only return for follow-ups if something later turns out
to be ambiguous.

What you typically need to nail down:

- **Project directory name** — propose 2-3 kebab-case options from
  the description, mark one as "(Recommended)".
- **The 2-3 roles** — propose role names and a one-line description of
  each. Confirm which is the primary/admin role (fully wired).
- **Entities + the inference chain** — list the entities you intend to
  model and, in plain English, the chain you intend to encode (e.g.
  "raw `Quantity` and `UnitPrice` → calc `LineTotal` → aggregated to
  parent → `OrderTotal` → thresholded → `IsLargeOrder`"). Ask the user
  to confirm or adjust.
- **Scope choices the domain makes ambiguous** — e.g. is there a time
  dimension (do we need a calendar)? Are there multiple physical
  locations or just one? Are there sub-types within a main entity?
  Don't ask about things you can default reasonably; do ask about
  things that meaningfully shape the schema.

Skip questions about UI library, styling, ports, test framework, build
tooling — those are decided by the defaults table below.

## The FK / lookup pattern (canonical)

Foreign keys store the **Name (PK)** of the referenced row, *not* a
synthetic numeric id, and *not* a column called `*Id`.

- `Widgets.Thing` holds the **value** of the related Thing's `Name`
  (e.g. `"blue-thing"`). This is the FK field itself.
- For every other Thing field you want visible on Widget rows, add a
  **lookup** that references `Widgets.Thing`:
  - `Widgets.ThingName`  — looks up Thing.Name through `Widgets.Thing`
  - `Widgets.ThingColor` — looks up Thing.Color
  - `Widgets.ThingPrice` — looks up Thing.Price

So the FK column and its lookups are all prefixed with the related
entity's singular name. No `ThingId`. No `thing_id`. Just `Thing`
(the FK value) plus `Thing<Field>` lookups for any field you want on
the Widget side.

Aggregations go the **other** way: on `Things` you might have
`TotalWidgetSpend = SUMIFS(Widgets!{{LineTotal}}, Widgets!{{Thing}}, {{Name}})`.

This is the pattern every entity uses. Calculated fields on `Widgets`
that need a related field do it through a lookup — they reference
`{{ThingPrice}}` (the lookup on Widgets), not Thing directly.

## Pitfalls baked into the rulebook generator

These are non-obvious things that will bite if you don't plan for them:

1. **Field-name inference can override declared `datatype`.** Names
   containing tokens like `*Time`, `*Date`, `*Period`, `*HHMM`, `*_at`
   may be coerced to `DATE` or `TIMESTAMPTZ` in the generated SQL even
   if you wrote `datatype: "string"`. If you need a free-text
   time-like field, use a neutral name (e.g. `ClockLabel`,
   `StartsAt` for a real datetime, `BillingTag` instead of
   `BillingPeriod`).

2. **`Name` is calculated; base tables don't have a `name` column.**
   The PK column on the base table is `<table>_id`. INSERT/UPDATE/
   DELETE must target `<table>_id`. The view re-derives `name` from
   its formula every read. Application writes only touch raw columns.

3. **Calculated PK formulas must compose from TEXT.** If `Name` uses
   `CONCAT(...)` of fields where one is coerced to DATE/TIMESTAMPTZ,
   the resulting string in the view won't match string FK values
   stored elsewhere (`CONCAT` on a timestamp emits
   `"2026-05-01 00:00:00-05"`, not `"2026-05-01"`). Workaround: add
   a raw `<Thing>Key` field, set it server-side to the desired slug,
   and make `Name = ={{<Thing>Key}}`.

4. **No native VLOOKUP in calculated formulas.** Cross-table reads
   happen via the FK/lookup pattern above (lookups follow the
   relationship FK) or via `SUMIFS`/`COUNTIFS` aggregations going the
   other direction. Calculated fields on a row only see fields on
   that same row (including lookups).

## Process — A through Z

Use `TodoWrite` to track these. Stop and verify at each checkpoint
before moving on.

### A. Plan

1. Read the user's description; if missing, offer the "pick for me"
   options described above.
2. Sketch the entities (3–5) and the inference chain on paper /
   internally. Confirm the chain has 2–3 hops.
3. Ask the questions you need (see "Questions to ask").

### B. Scaffold

4. Create `<project-dir>/` with:
   - `effortless.json` (transpilers: `rulebook-to-postgres → /postgres`,
     then `execute ./init-db.sh`).
   - `CLAUDE.md` (project conventions — Path B, no migrations, etc.).
   - `start.sh` (interactive launcher with subcommands
     `all|server|web|db|build`).
5. Pick ports unlikely to collide with other demos.

### C. Rulebook

6. Author `effortless-rulebook/effortless-rulebook.json`:
   - Entities in **DAG order** — leaf tables first, then dependents.
   - For each entity: `Name` calculated PK formula derived from a raw
     field; the raw fields; the FK fields + their lookups (see
     pattern above); calculated fields (1st/2nd/3rd-order); any
     aggregations from related tables.
   - Mock data: for every boolean/threshold/enum rule, seed rows that
     produce each possible output. The dashboard for the primary role
     should show a mix of states out of the box.

### D. Build the DB

7. `effortless build` (regenerates `postgres/`).
8. Drop+create the DB:
   `psql -U postgres -h localhost -c "DROP DATABASE IF EXISTS <db>"`
   then `CREATE DATABASE`.
9. `chmod +x postgres/init-db.sh && DATABASE_URL=... ./postgres/init-db.sh`.
10. Quick verification: one `psql -c "SELECT … FROM vw_<table>"` that
    shows a calculated field rendering with the seed data — cheap
    proof the DAG works.

### E. Server

11. `server/package.json` (express, pg, tsx, typescript).
12. `server/src/index.ts` (single file):
    - `pg` Pool connecting as `postgres` (no RLS for demos).
    - Auth middleware: read `X-User-Email`, look up `vw_users`,
      attach `req.me`.
    - Public route: `GET /api/dev-users` (the login picker).
    - For each table: `GET /api/<table>s`, `GET /api/<table>s/:id`,
      `PATCH /api/<table>s/:id` for the editable raw fields.
    - Reads hit `vw_*` views (with calculated/aggregated columns).
      Writes hit base tables, only touching raw columns, keyed on
      `<table>_id`.
    - Role-filter in the route handlers from `req.me.role`.
13. Boot it; curl `/healthz` and one read+patch+read cycle showing the
    cascade.

### F. Web

14. `web/package.json` (react, react-router-dom, vite,
    `@vitejs/plugin-react`, plus FullCalendar packages if scheduling).
15. `web/vite.config.ts` (proxy `/api` to the server port).
16. `web/src/`:
    - `main.tsx` → `<BrowserRouter><App /></BrowserRouter>`.
    - `App.tsx`: load `/api/me` once, render `<Login>` if 401, else
      `<Shell>` with a `<Routes>` block — one `<Route>` per page.
      Role-guarded routes redirect via `<Navigate to="/" replace />`.
    - `Shell.tsx` + `nav.ts`: sidebar nav, grouped, role-specific via
      `navFor(role)`.
    - `Login.tsx`: fetch `/api/dev-users`, render clickable identities
      grouped by role.
    - `lib/api.ts`: `fetch` wrapper that adds `X-User-Email`.
    - `lib/useApi.ts`: `useEffect`-based hook with a `reload()`
      callback so edits can refresh the view.
    - `pages/`:
      - **Primary role**: dashboard with calculated/aggregated stats,
        list pages, detail pages, and **edit forms for the raw
        fields that drive the DAG**.
      - **Other roles**: a single `Placeholder.tsx` page that
        describes the role's intended view and links back to the
        primary role's home for the demo.
    - `styles.css`: hand-rolled, minimal.
17. `npx tsc --noEmit` to confirm typecheck.
18. Boot both server and web; load the SPA, log in as primary role,
    edit a raw field, watch the dependent calculated field update.

### G. README

19. Write `README.md` with:
    - Two-paragraph narrative: what the app does and who uses it.
    - A plain-English explanation of the DAG, pointing at the 2-3
      hop chain.
    - Quick-start (`./start.sh`).
    - Dev-login table (emails + roles).
    - **"Try this" walkthrough**: a 3-step path that exercises the
      cascade end-to-end. e.g. "log in as primary role → open Thing
      X → edit its `Quantity` from 5 to 50 → watch `LineTotal` and
      the rolled-up `OrderTotal` update, and the threshold flag flip".
    - Repo layout.
    - Leopold loop instructions ("to add a field: edit the rulebook,
      `./start.sh build`, `./start.sh db`").
    - Known limitations (stub auth, no RLS, placeholder roles, no
      tests).

### H. Smoke test before declaring done

20. `./start.sh all` boots cleanly.
21. Login picker shows all seeded identities; signing in as the
    primary role lands on a populated dashboard.
22. Editing one raw field that feeds the DAG visibly updates the
    dependent calculated field on the next read.
23. Hitting a primary-only route as a placeholder role redirects to
    `/`.
24. Hard-refresh (F5) on a deep URL re-renders the same page.

If any check fails, fix it before reporting back.

## Decision defaults (don't ask, just do)

| Thing | Default |
|---|---|
| Ports | server :3032+, web :5175+ (pick unused) |
| DB name | snake_case of project name |
| Test runner | none — manual smoke tests are enough for a demo |
| Styling | hand-rolled CSS in `web/src/styles.css`, no UI framework |
| State management | React `useState` + the `useApi` hook |
| Forms | local `useState`, `PATCH` on submit |
| Number/date formatting | small `lib/fmt.ts` helpers |
| Calendar | FullCalendar React (only if the domain has a time dimension) |
| FK enforcement | leave `99-fk-constraints.sql` skipped |
| RLS | enabled by generator but no policies; server connects as superuser |
| TypeScript `strict` | yes |

## What success looks like

When you hand back to the user, they should be able to:

1. Run one command and have a working app open in the browser.
2. Sign in as the primary role and see a dashboard with at least one
   calculated/aggregated number derived from the DAG.
3. Edit a raw field on some row and see a downstream calculated field
   change on the next read (or with one obvious refresh).
4. Sign in as a placeholder role and see a labeled stub page with a
   working role switch back.
5. Read the README and understand the domain, the DAG, and the
   "try this" walkthrough in under two minutes.

If any of those don't work, you're not done.
