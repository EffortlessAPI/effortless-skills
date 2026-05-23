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

## User-facing documentation discipline

**README and user-facing docs lead with business value, not the ERB.**

The README should open with what the app *does* — the domain, the primary
user persona, the business outcomes. Mention ERB only as an implementation
detail, far down or in a separate architecture section. Example:

- ❌ *"This is an Effortless Rulebook project showcasing multi-hop
  calculated fields and the Leopold loop..."*
- ✅ *"An event planning system for community organizers, with automatic
  conflict detection and capacity forecasting. See the 'Next 10 loops'
  section for guided feature suggestions."*

The rulebook DAG, inference chains, and transpiler plumbing are *why* the
system works, not *what* it is. Keep them invisible to the end user in
the README. They belong in CLAUDE.md and developer guides.

## Speed discipline (read this first)

This skill exists because demos should be FAST. Target: first
`effortless build` invocation within ~30 seconds of the user request,
working app within a few minutes. The most common failure mode is
noodling — exploring, re-reading skills, re-checking the same directory,
authoring the rulebook in two passes, retrying `init-db.sh` four times
with incremental tweaks. Don't.

**The bootstrap path is deterministic. Just run it:**

1. `mkdir <project>/effortless-rulebook` (one shot)
2. `effortless -init` (in the project dir)
3. Write `effortless-rulebook/effortless-rulebook.json` **completely in one
   Write call** — full schema, mock data, all entities. Do not write a
   partial version and revise.
4. Write `effortless.json`, `CLAUDE.md`, `start.sh`.
5. `./start.sh build` (or the documented equivalent). **Run it the
   moment you've decided to.** Do not pre-flight with `ls`, `cat
   ssotme.json`, `effortless -list`, `effortless --help`, ToolSearch,
   or "let me first check…". The build is the check.

**Don't do** (specific noodling patterns observed in real sessions):

- Repeated `ls` / `head` / `wc` / `cat` of the parent project dir
  "looking for patterns" — you already have the patterns in this skill
- Loading the seven prerequisite skills sequentially in seven separate
  turns. If you need them, load in parallel; better, only load the
  ones a specific step actually requires
- AskUserQuestion to "confirm scope" before doing anything — if the
  user gave you a domain, start; if they didn't, ask ONCE with the
  pick-for-me options and proceed
- Writing the rulebook, pausing to "think", then rewriting it. Hold
  the design in your head, then emit it once
- Running `effortless -install <transpiler>` more than once. If it
  fails, read the error before re-running with tweaks
- `chmod +x init-db.sh` defensively — the transpiler emits it
  executable. Only chmod if the actual error says permission denied
- Loading the `effortless-demo-app` skill twice
- Running ToolSearch for transpiler names or React explainer features
  during bootstrap — irrelevant to first-build

**Ask-before-building exception:** outside this demo skill, you should
generally confirm before running `effortless build` (it drops the DB).
**Inside this skill, do not ask** — the user invoked the demo flow,
which means they want the build to happen. Only ask if a non-default
choice (e.g. wiping an existing DB with the same name) actually needs
their input.

A single brief "running build now" status line is fine. A paragraph
of deliberation is not.

## Load supporting skills lazily, not up front

Do NOT preload all seven supporting skills before starting. The bootstrap
path in "Speed discipline" above doesn't need them. Load on demand:

- `effortless-schema` — **required** before authoring the rulebook
  (step C); it defines the JSON shape, field types, and formula syntax
- `effortless-conventions` — only if you hit a naming/DAG question you
  can't answer from this skill
- `effortless-sql` — only when wiring server-side queries
- `effortless-setup-postgres` / `effortless-pipeline` — only if the
  build fails in a way that needs pipeline-level debugging
- `effortless-leopold-loop` — only when documenting the edit→build
  loop in the README

Skip entirely for demos: `effortless-airtable*`, `effortless-bootstrap`
(Shadle steps), `effortless-magic-links`, `effortless-bases`,
`effortless-orchestrator` (its content is summarized inline here).

## Commit cadence: one commit per Leopold loop

The pedagogical point of this skill is to **show the Leopold loop
turning**. The git log should read like a walkthrough of loop
turns, not one giant blob and not a flood of micro-commits.

**The rule: one commit per Leopold loop.** A loop is a single
coherent feature — the initial scaffold-to-running-app is loop
zero (one commit), and each suggested next-10-loops item the user
picks is its own single commit covering rulebook + regenerated
`postgres/` + any UI changes that loop required.

So the typical demo git log looks like:

1. `feat: initial <domain> demo — rulebook, postgres, server, web, README`
2. `feat: round LineTotal to 2 decimals` (rulebook-only loop)
3. `feat: add Discount entity` (rulebook + UI loop)
4. …

Rules:

- Commit at the end of each loop, not in the middle. Don't pile
  multiple loops into one commit — that's what drives the user
  crazy.
- Use `git add <specific paths>`, never `git add -A` / `git add .`.
- Don't skip hooks. Don't amend.
- If the tree is dirty when the user invokes the demo, stop and
  ask before doing anything — don't pile demo commits on top of
  unrelated work.

## Invariants (do these, don't ask about them)

1. Postgres + rulebook-direct (no Airtable). The SSoT is
   `effortless-rulebook/effortless-rulebook.json` — the hub. Demo apps are
   the canonical **LLM + ERB + Postgres** shape: an LLM tends the JSON hub
   directly, `effortless build` generates the Postgres substrate.
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

Default to **zero questions** if the user gave you a domain. Pick
reasonable defaults for everything in the "Decision defaults" table
and infer the entities + inference chain from the domain. Only ask
when a choice meaningfully changes the schema AND you can't pick a
sensible default. If you must ask, do it in a **single**
`AskUserQuestion` batch up front, then proceed without further
prompts unless something is later truly ambiguous.

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

The `rulebook-to-postgres` transpiler uses **the first raw field of
each entity as its literal PK column** (named `<table>_id` in the
generated SQL). Foreign keys store the value of that PK field. This
is what every generated `vw_*` view, every `calc_*` lookup function,
and every aggregation actually joins on. The Name-as-PK pattern (FK
column holding a calculated `Name` value) does **not** work — the
transpiler's emitted lookups will join on `<table>_id`, which won't
match the Name-derived FK value, and every lookup will silently
return NULL.

So every entity has the same shape:

- First raw field: `<Table>Id` (PascalCase singular `<Entity>` + `Id`,
  e.g. `ThingsId`, `WidgetsId`, `UsersId`). Holds the slug / email /
  natural key.
- `Name = ={{<Table>Id}}` as the calculated PK (so the view still has
  a friendly `name` column for display).
- FK columns are named after the related entity (singular). E.g.
  `Widgets.Thing` holds the value of `Things.ThingsId`. No
  `Widgets.ThingId`, no `Widgets.thing_id` — just `Widgets.Thing`.
- Lookups follow the FK: `Widgets.ThingName`, `Widgets.ThingColor`,
  etc. The lookup formula is
  `=INDEX(Things!{{Color}}, MATCH(Widgets!{{Thing}}, Things!{{ThingsId}}, 0))`
  — **match against `<Table>Id`, never against `Name`.**
- Chained lookups work too: a lookup on Widgets can pull a lookup from
  Things (e.g. `Widgets.ThingCategoryName` pulls
  `Things.CategoryName`, which is itself a lookup). The transpiler
  resolves them transparently.

Aggregations go the **other** way: on `Things` you might write
`TotalWidgetSpend = SUMIFS(Widgets!{{LineTotal}}, Widgets!{{Thing}}, {{ThingsId}})`.

Calculated fields on Widgets that need a related field reference the
lookup (`{{ThingPrice}}`), not the related entity directly.

**Cross-table SQL is forbidden in customize files.** If a relationship
you need isn't expressible as a rulebook lookup, the answer is to add
the lookup to the rulebook — never to write a `LEFT JOIN` in
`03b-customize-views.sql` or a cross-table subquery in app code. The
whole point of `vw_*` is that it's join-free.

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

4. **Don't put `LEFT JOIN` in `*b-customize-views.sql`.** If a lookup
   isn't resolving, the bug is in the rulebook FK pattern (almost
   always: FK column holds a `Name` value instead of a `<Table>Id`
   value), not something to paper over with a JOIN view. The
   `customize-*` files are for additive views/columns/functions that
   honor the join-free `vw_*` discipline — not an escape hatch for
   broken lookups. Same goes for cross-table subqueries in app code:
   if you're writing `WHERE x IN (SELECT y FROM other_view)` to scope
   results, add a (possibly chained) lookup column instead and filter
   on that.

5. **No native VLOOKUP in calculated formulas.** Cross-table reads
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
   - `CLAUDE.md` (project conventions — rulebook-direct, no Airtable, no migrations, etc.).
     **The first line under the H1 MUST explicitly mark this as an
     Effortless demo project** so future Claude sessions auto-load
     the `effortless-demo-app` skill (and the standard ERB skills)
     when working in this directory. Use exactly this marker line:
     `> **Project type:** Effortless demo app (rulebook-first
     Postgres POC). Use the \`effortless-demo-app\` skill for any
     work in this repo — schema edits, Leopold loops, new pages,
     mock data, README updates.`
     Also include the standard ERB marker sentence ("This project
     follows the Effortless Rulebook (ERB) methodology…") so the
     project-only effortless-* skills load via their scope gate.

     **CLAUDE.md MUST also include a `## Git hygiene` section that
     promotes the commit cadence into the project itself**, so
     every future Claude session in this repo follows it without
     needing to reload this skill. Use this wording (verbatim):

     ```
     ## Git hygiene

     One commit per Leopold loop. A loop = one coherent feature
     (rulebook change + regenerated postgres/ + any UI changes
     that loop needs), committed together at the end.

     - Don't bundle multiple loops into one commit.
     - Don't split a single loop across many micro-commits.
     - Use `git add <specific paths>`. Never `git add -A` /
       `git add .`.
     - Don't wait to be told to commit at the end of a loop —
       just do it.
     ```

     Top-level section, not a sub-bullet.
   - `start.sh` (interactive launcher with subcommands
     `all|server|web|db|build`).
5. Pick ports unlikely to collide with other demos.

### C. Rulebook

6. **Load `effortless-schema` before writing the rulebook.** That
   skill is the canonical source for the JSON structure — top-level
   keys, table objects, field schema, field types (raw / calculated
   / lookup / relationship / aggregation), datatypes, formula
   syntax, and the `_meta` section. Don't author the rulebook from
   memory or by pattern-matching another project — load the schema
   skill and follow it. This is the one supporting skill that
   actually *is* required for the rulebook step.

7. Author `effortless-rulebook/effortless-rulebook.json`:
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
8. **Immediately patch `postgres/init-db.sh` to use this project's DB
   name.** The transpiler ships a sensible generic default
   (`DEFAULT_CONN=postgresql://postgres@localhost:5432/demo` + header
   `# demo - Database Initialization Script`) — that default is fine
   for the transpiler but WRONG once it lands in a named project.
   Leaving `demo` in place means anyone running `./init-db.sh` with no
   `DATABASE_URL` set will silently target a `demo` DB unrelated to
   this project. This skill *creates* a named project, so it is THIS
   skill's job to overwrite the default — do not file a bug against
   the transpiler. Before doing anything else:
   - `sed`/Edit `DEFAULT_CONN` → `postgresql://postgres@localhost:5432/<db>`
   - Update the header comment line to `# <db> - Database Initialization Script`
   Re-apply on every regeneration if the transpiler stomps it back.
   Same `<db>` should be the `DATABASE_URL` default in `start.sh`.
9. Drop+create the DB:
   `psql -U postgres -h localhost -c "DROP DATABASE IF EXISTS <db>"`
   then `CREATE DATABASE`.
10. `chmod +x postgres/init-db.sh && DATABASE_URL=... ./postgres/init-db.sh`.
11. Quick verification: one `psql -c "SELECT … FROM vw_<table>"` that
    shows a calculated field rendering with the seed data — cheap
    proof the DAG works.

### E. Hello-world web app (BEFORE the server)

The point of doing the web app first — even as a stub — is so the
user sees *something running in a browser* very early in the demo,
and so the explainer DAG can be wired in before any real UI exists.
This means as soon as the real UI is built, every calculated cell
is already explainer-aware from the first render. No retrofit.

12. Scaffold `web/`:
    - `web/package.json` (react, react-router-dom, vite,
      `@vitejs/plugin-react`).
    - `web/vite.config.ts` (proxy `/api` to the planned server port
      — the proxy can 502 for now, that's fine).
    - `web/index.html`, `web/src/main.tsx`, `web/src/App.tsx` that
      renders a literal **"<Project Name> — coming soon"** placeholder
      with a one-line description of the domain. No routing, no
      data fetching, no auth. Just text.
    - Add `node_modules/`, `dist/`, `.vite/` to `.gitignore` (append
      to the project-root `.gitignore` that already has `.ssotme/`).
13. `start.sh` (if not already present) — interactive launcher with
    subcommands `all | server | web | db | build`. The `web`
    subcommand runs `cd web && npm install && npm run dev`.
14. Run `./start.sh web`, then **open the URL in the browser** (the
    assistant should print the URL and, where possible, open it).
    Confirm the "coming soon" placeholder renders before moving on.
    This is the first time the user sees *anything* — make it count.

### F. Explainer DAG (BEFORE real UI)

15. Load the `effortless-react-explainer-dag` skill and wire it into
    the hello-world `web/` app *now*, while the UI is trivial. The
    explainer reads from `effortless-rulebook.json` and exposes
    `<DagCell>`, `<DagToggle>`, `<FieldDag>` (or equivalent — defer
    to that skill for exact API). Goal: by the time the real UI
    pages get built, every calculated value is already wrapped in a
    `<DagCell>` so the inference graph is visible from the first
    render. Don't bolt it on later.

### G. Server

16. `server/package.json` (express, pg, tsx, typescript). Use
    `tsx watch src/index.ts` (not plain `tsx`) so the server
    auto-restarts on edits — there's no reason to manually bounce
    it during a demo.
17. `server/src/index.ts` (single file):
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
18. Boot it via `./start.sh server`; curl `/healthz` and one
    read+patch+read cycle showing the cascade.

### H. Flesh out the real UI (with explainer tokens from the start)

Replace the "coming soon" placeholder with the real app. Because the
explainer was wired in step F, every calculated value rendered here
should already use `<DagCell>` / `<FieldDag>` — not as a follow-up
pass.

19. `web/src/`:
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
      - **Primary role**: dashboard with calculated/aggregated stats
        (each wrapped in `<DagCell>`), list pages, detail pages, and
        **edit forms for the raw fields that drive the DAG**.
      - **Other roles**: a single `Placeholder.tsx` page that
        describes the role's intended view and links back to the
        primary role's home for the demo.
    - `styles.css`: hand-rolled, minimal.
20. `npx tsc --noEmit` to confirm typecheck.
21. Confirm the SPA: log in as primary role, edit a raw field, watch
    the dependent calculated field update — and watch the DAG popover
    explain *why* it changed.

### I. README

22. Write `README.md` with:
    - **Two-paragraph narrative opening with what the app does and who uses
      it — the business angle, not the methodology.** (E.g., "An event
      planning system for community organizers..." NOT "An Effortless
      Rulebook demo showing multi-hop inferences...")
    - A plain-English explanation of how the system computes key
      outcomes, referencing the 2-3 hop chain (but keep ERB jargon
      buried or in footnotes).
    - Quick-start (`./start.sh`).
    - Dev-login table (emails + roles).
    - **"Try this" walkthrough**: a 3-step path that exercises the
      cascade end-to-end. e.g. "log in as primary role → open Thing
      X → edit its `Quantity` from 5 to 50 → watch `LineTotal` and
      the rolled-up `OrderTotal` update, and the threshold flag flip".
    - Repo layout.
    - Leopold loop instructions ("to add a field: edit the rulebook,
      `./start.sh build`, `./start.sh db`").
    - **"Next 10 Leopold loops" section** (see below).
    - Known limitations (stub auth, no RLS, placeholder roles, no
      tests).
    - Optional: a "How This Was Built" section at the end explaining
      the ERB infrastructure for developers interested in the internals.

### G.1 The "Next 10 Leopold loops" suggestions

The first-build demo is just the **top of the loop for the first
time**. The README must end with a numbered list of 10 concrete,
*suggested* next-turn changes the user could pick from. Don't
implement them — list them. After the README is written, surface
this list to the user and ask which (one, several, or all in order)
they want to actually crank through.

Rules for the list:

- Each item is one additional inference (or small cluster of
  inferences) the current model doesn't yet have but obviously
  *could*. Phrase it as the rule change, not the implementation.
- **Alternate / mix two flavors**, roughly half and half:
  - **Rulebook-only loops** — change a formula, threshold, tax
    rate, weighting, add a derived flag, add an aggregation. The
    UI keeps working unchanged because it just reads `vw_*` and
    the new/changed column rides along (or the changed value
    flows through existing columns). Call these out as
    "rulebook-only — no UI change needed".
  - **Rulebook + UI loops** — introduce a new entity, a new raw
    field that needs an editor, a new role-visible concept (e.g.
    Discounts, Refunds, Categories, Tiers). Call these out as
    "rulebook + UI — new editor / page / column".
- Order them from smallest blast radius to largest, so the user
  can see the loop tighten before it widens.
- Each entry: one-line title + one sentence describing the
  inference change + the `[rulebook-only]` or `[rulebook + UI]`
  tag.
- These are *suggestions*, not a roadmap. The user picks. Be
  confident about each one — by the time you've built the first
  pass you should know the domain well enough that all 10 are
  plausible next turns, not speculation.

Example shape (illustrative, not domain-specific):

```
1. Round LineTotal to 2 decimals  — change the formula to use ROUND. [rulebook-only]
2. Add a TaxRate constant and a Tax calc on each line. [rulebook-only]
3. Flag any Order whose Total exceeds $1000 as IsLargeOrder. [rulebook-only]
4. Add a Discount entity with a percent applied per Order. [rulebook + UI]
...
```

After writing the README, the assistant's hand-back message should
include this list inline and explicitly ask which loops to run
next.

### J. Smoke test before declaring done

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
6. See a list of the **next 10 Leopold loops** at the bottom of the
   README — a mix of rulebook-only and rulebook+UI changes — and
   pick which one(s) to run next.

If any of those don't work, you're not done.
