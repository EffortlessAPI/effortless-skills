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

This skill is for **demos and POCs**, not production. No Airtable, no
magic-links, no Shadle steps, no migration tooling. The goal is shortest
possible loop from idea to "here, click around".

## Load these skills first

Before doing any work, load (in this order):

1. `effortless-orchestrator` — mental model + token discipline
2. `effortless-setup-postgres` — postgres pipeline setup (the parts that
   apply to Path B; skip the Airtable-pull steps)
3. `effortless-conventions` — naming rules, DAG structure, PascalCase tables,
   Name field formula, why no M:N
4. `effortless-schema` — JSON shape of `effortless-rulebook.json`
5. `effortless-pipeline` — `effortless.json`, transpiler catalog, build flow
6. `effortless-sql` — read views, write base tables, calculated functions
7. `effortless-leopold-loop` — the edit-rulebook → build → consume loop

You do NOT need: `effortless-airtable*`, `effortless-bootstrap` (Shadle
steps), `effortless-magic-links`, `effortless-bases`. This is a local-only
demo.

## The invariants — never ask about these

These are baked in. Don't waste a question on them:

1. **Postgres + rulebook-first (Path B).** No Airtable. SSoT is
   `effortless-rulebook/effortless-rulebook.json` in the new project repo.
2. **Stack: Express + Vite + React + React Router.** Single-file Express
   server (`server/src/index.ts`), Vite SPA in `web/`.
3. **Dev login for 2-3 roles.** Email-only `X-User-Email` stub auth.
   Login page reads `/api/dev-users` and lets the user pick any seeded
   identity. **No magic links.**
4. **Every page has its own route** — F5 always lands you on the same
   page. Role-guarded routes use `<Navigate replace />` instead of
   conditional rendering. Deep links to detail pages work cold-load.
5. **Admin role is fully wired; other roles get a placeholder page** that
   describes what they'd see and links back to admin. (User can iterate
   per-role later.)
6. **README first.** Write a brief narrative-style README before/while
   coding so the human and the agent both understand what's being built.
7. **Multi-hop calculated DAG.** Rulebook MUST include at least one
   inference chain of 2–3 hops (raw → 1st-order → 2nd-order → optional
   3rd-order). Total: 3–5 entities, 1–2 inferences per entity minimum.
8. **Key fields are editable.** The UI must let the user edit the raw
   fields that feed the DAG, so they can watch cascading recomputation
   live. (`PATCH /api/<table>/:id`, then re-read the view.)
9. **Mock data flexes every inference.** For every boolean/threshold
   inference (e.g. `IsVIP = TotalSales > 100`), seed at least one row
   on each side of the threshold so the UI shows both states. For
   every enum-producing inference, seed one row per enum value.

## Questions to ask (and only these)

Ask in a single `AskUserQuestion` batch up front, then go. Don't ask
mid-build — make judgment calls and note them in the README.

The four questions:

1. **Project directory name?** Suggest 2–3 kebab-case options derived
   from the user's description; mark the most natural one as
   "(Recommended)". Always include a "type my own" implicit option
   (AskUserQuestion gives the user "Other" automatically).

2. **The 2-3 roles?** Propose role names + a one-line description of
   what each does. The first role listed becomes the **fully-wired
   admin/primary** role; the others are placeholder pages.

3. **Domain-specific scope choices** — 1–2 questions, max. Things that
   *meaningfully shape the rulebook* and can't be reasonably guessed.
   For an autobody shop: "track labor hours too, or just parts?";
   "should we model multiple physical locations or one shop?". Skip
   anything you can reasonably default — never ask about UI library,
   styling, build tooling, port numbers, etc.

4. **(Optional, only if ambiguous) Calendar/scheduling?** If the domain
   plausibly has a time dimension (appointments, classes, jobs), ask
   whether the demo needs a calendar view. Otherwise skip.

That's it. **No more than 4 questions total.** Anything else, decide
yourself and note the decision in the README's "Choices made" section.

## Process — A through Z

After the questions, work the list. Use `TodoWrite` to track these:

1. **Scaffold the project**
   - Create `~/<your-projects-dir>/<name>/` with:
     - `effortless.json` (transpilers: `rulebook-to-postgres` → `/postgres`,
       then `execute ./init-db.sh`)
     - `CLAUDE.md` (project conventions — Path B, no migrations, etc.)
     - `start.sh` (interactive launcher: `all|server|web|db|build`)
   - Pick unique ports (avoid 3000/3030/5173 collisions with other demos).

2. **Author `effortless-rulebook/effortless-rulebook.json`**
   - 3–5 entities. Each table: PascalCase, has a `Name` calculated PK
     formula derived from a raw field, and a few raw fields.
   - **DAG order matters** — leaf tables first, dependents after.
   - At least one **2-3 hop inference chain**, e.g.:
     - raw `Quantity` + raw `UnitPrice` → calc `LineTotal` (1st hop)
     - calc `LineTotal` aggregated to parent → `OrderTotal` (2nd hop)
     - calc `OrderTotal` thresholded → `IsLargeOrder` (3rd hop)
   - Seed data MUST flex every inference (see invariant #9).
   - **Avoid the transpiler's date-name inference trap.** Field names
     containing `*Time`, `*Date`, `*Period`, `*HHMM`, `*_at` will be
     forced to DATE/TIMESTAMPTZ regardless of declared `datatype`. If
     you need a free-text time-like field, name it something neutral
     (e.g. `ClockLabel` not `StartTime`).
   - **Calculated keys must compose from TEXT.** If `Name` uses
     `CONCAT(...)` of fields, one of which is forced-to-DATE, the
     resulting PK string won't match FK references. Workaround: add
     a raw `<Thing>Key` field the server fills with the slug, and
     make `Name = ={{<Thing>Key}}`. (See gym-trainer-invoicing.)

3. **Build & init DB**
   - `effortless build` (regenerates `postgres/`).
   - Create DB: `psql -U postgres -h localhost -c "CREATE DATABASE <db_name>"`
     (drop first if it exists).
   - `chmod +x postgres/init-db.sh && DATABASE_URL=... ./postgres/init-db.sh`.
   - Verify with one `psql -c "SELECT ... FROM vw_<key_table>"` showing
     a calculated field — cheap proof the DAG works.

4. **Server (`server/`)**
   - Single-file `src/index.ts`. Express + `pg`. Dev auth middleware
     reads `X-User-Email`, looks up the user in `vw_users`, attaches
     `req.me`.
   - Public: `GET /api/dev-users` for the login picker.
   - For each table: `GET /api/<table>s`, `GET /api/<table>s/:id`,
     and `PATCH /api/<table>s/:id` for the editable raw fields.
   - **Read views (`vw_*`), write base tables.** Base tables don't have
     a `name` column (it's calculated) — PK column is `<table>_id`.
   - Role-filter in-route based on `req.me.role`.
   - Single `package.json`, `tsconfig.json`, `tsx` for dev.

5. **Web (`web/`)**
   - Vite + React + React Router + (FullCalendar if scheduling).
   - `App.tsx`: top-level role check, then a `<Routes>` block with one
     `<Route>` per page. Role-guarded routes redirect via
     `<Navigate to="/" replace />` — never conditional render.
   - `Shell.tsx`: nav sidebar; `nav.ts` exports a `navFor(role)`
     function returning grouped links.
   - `Login.tsx`: fetch `/api/dev-users`, render clickable identities
     grouped by role.
   - `pages/`:
     - Admin role gets the fully-wired pages: dashboard with
       calculated-field stats, list pages, detail pages, **edit forms
       for the raw fields that drive the DAG**.
     - Other roles get a single `Placeholder.tsx` page describing
       what they'd see, with a "go to admin" link (for the demo).
   - `lib/api.ts`: thin `fetch` wrapper that adds `X-User-Email`.
   - `lib/useApi.ts`: simple `useEffect` + state hook with a
     `reload()` callback (so edits can refresh the view).

6. **README (write early, finalize last)**
   - Two-paragraph narrative: what the app does and who uses it.
   - The DAG explained in plain English — point at the 2-3 hop chain
     and what fields cascade.
   - Quick-start (`./start.sh`).
   - Dev-login table (emails + roles).
   - "Try this" walkthrough: a 3-step path that exercises the cascade.
     E.g. "log in as Admin → open Customer X → edit TotalSales from
     50 to 150 → watch IsVIP flip and the dashboard count change".
   - Repo layout + Leopold loop instructions.
   - Known limitations (always include: stub auth, no RLS, placeholder
     roles, no tests).

7. **Smoke test end-to-end before declaring done**
   - Boot server + web.
   - Hit `/healthz`, `/api/dev-users`, `/api/me` (with header).
   - Verify one read of a calculated field via the view.
   - Verify one PATCH on a raw field cascades through the DAG (re-read
     the view, confirm the dependent calc changed).
   - Verify the role-redirect: log in as non-admin, hit an
     admin-only route, confirm bounce to `/`.

## Decision defaults (don't ask, just do)

| Thing | Default |
|---|---|
| Ports | server :3032+, web :5175+ (pick unused) |
| DB name | snake_case of project name |
| Node test runner | none — manual `curl` smoke tests are enough for a demo |
| Styling | hand-rolled CSS in `web/src/styles.css`, no UI framework |
| State management | React `useState` + the `useApi` hook, no Redux/zustand |
| Forms | uncontrolled-ish: local `useState`, `PATCH` on submit |
| Money/date formatting | small `lib/fmt.ts` helpers |
| Calendar | FullCalendar React (only if scheduling is in scope) |
| FK enforcement | leave the `99-fk-constraints.sql` skip in place |
| RLS | enabled by generator but no policies; server connects as `postgres` |
| TypeScript `strict` | yes |

## Reference implementation

The `gym-trainer-invoicing` project is the canonical worked example of this
skill. If you're unsure how something should look (rulebook shape, server
route style, page layout, the `InvoiceKey` workaround, etc.), open it and
copy the pattern.

## What success looks like

When you hand back to the user, they should be able to:

1. `./start.sh all` and have a working app open at the web URL.
2. Sign in as the admin role and see a dashboard with at least one
   calculated/aggregated number.
3. Edit a raw field on some row and see a downstream calculated field
   change without refreshing (or with one obvious refresh button).
4. Sign in as a placeholder role and see a labeled stub page with a
   working role switch.
5. Read the README and understand the domain, the DAG, and the
   "try this" walkthrough in under two minutes.

If any of those don't work, you're not done. Fix it before reporting back.
