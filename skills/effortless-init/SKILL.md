---
name: effortless-init
description: >
  Use when initializing a new effortless project: "make this an effortless
  project", "init effortless", "init effortless project", "set up effortless
  here", "connect to Airtable", "hook up Airtable", or when an existing project
  is missing CLAUDE.md / start.sh / the standard ERB directory layout.
  Covers `effortless -init`, the standard directory structure, the Airtable
  connection sequence, the project-level CLAUDE.md template, and start.sh.
  For Postgres-targeted first-run (preflight checks, init-db, full 7-step
  bootstrap), use effortless-setup-postgres instead — that skill is a superset
  for postgres projects.

  **Scope (load gate):** Effortless projects, OR when the user explicitly asks to make a project Effortless / set up Effortless tooling.
audience: customer
---

# Effortless Project Initialization

This skill bootstraps a new ERB project. For Postgres-targeted projects, jump straight to **effortless-setup-postgres** — it includes everything here plus DB setup. Use this skill for non-postgres or pre-DB initialization.

## Step 1 — Init the CLI project

```bash
effortless -init -projectName "Project Name"
```

Creates `effortless.json` in the project root. Verify login first with `effortless -info` (see effortless-cli for login flow).

## Step 2 — Standard directory layout

```
project-root/
  effortless.json
  CLAUDE.md                 # see template below
  start.sh                  # see template below
  bootstrap/                # raw-text-to-rulebook output (optional)
  effortless-rulebook/      # airtable-to-rulebook output
    push-to-airtable/       # reverse sync (DISABLED by default)
  postgres/                 # rulebook-to-postgres output (if using postgres)
  docs/                     # rulebook-to-docs output (optional)
```

## Step 3 — Connect to Airtable

```bash
effortless -setAccountAPIKey airtable=patXXXX.XXXX     # if not already set
```

Set `baseId` in `effortless.json` ProjectSettings, then install the rulebook transpiler **from inside `/effortless-rulebook/`** (this is load-bearing — see ORCHESTRATION RULE in effortless-orchestrator):

```bash
cd effortless-rulebook/
effortless -install airtable-to-rulebook -o effortless-rulebook.json -account airtable

cd push-to-airtable/
effortless -install rulebook-to-airtable -i ../effortless-rulebook.json -account airtable
# Mark as "IsDisabled": true in effortless.json — only run with `effortless build -id`
```

Then `effortless build` to pull the first rulebook.

## Step 4 — Write CLAUDE.md (CRITICAL)

Without this, future Claude sessions break the methodology. Drop this in the project root, filling in `{ProjectName}` and `{baseId}`:

````markdown
# Project: {ProjectName}

This is an Effortless Rulebook (ERB) project. All development follows the effortless methodology.

## CRITICAL RULES — Read Before Doing Anything
1. **Airtable is the Single Source of Truth** — schema changes go through Airtable first, then `effortless build`.
2. **NEVER edit generated files** — files 00-05 in postgres/ are regenerated on every build.
3. **Always read from vw_* views**, never base tables. Always WRITE to base tables directly.
4. **Query the rulebook FIRST** — `effortless-rulebook/effortless-rulebook.json` has everything. Don't grep generated code.
5. **Ask permission** before modifying the rulebook, Airtable, or running `effortless build`.
6. **Always run `effortless build`** after any Airtable schema or data change.
7. **Never reimplement business logic** in app code — consume calculated fields from views as opaque truth.

## Airtable Base
- Base ID: {baseId}
- API Key: stored in ~/.ssotme/ssotme.key (set via `effortless -setAccountAPIKey airtable=...`)
- Use the Airtable REST API for scalar field changes and CRUD.
- Use OMNI (Playwright) for formula / lookup / rollup fields and new tables:
  `node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs {baseId} '<prompt>'`

## The Leopold Loop
CHANGE RULE (in Airtable) → `effortless build` → CONSUME generated views in app code → repeat.
On "do a turn" / "rebuild", load **effortless-leopold-loop**.

## Build & Start
- Build: `effortless build` from project root
- Start: `./start.sh` from project root

## ERB Skills
All conventions live in the effortless-* skills. Routing starts at **effortless-orchestrator**.
````

## Step 5 — Write start.sh

Idempotent launcher; pick one stable 3-digit prefix per project so backend (`nnn4`) and frontend (`nnn2`) ports don't collide across your projects.

```bash
#!/bin/bash
PORT_PREFIX=847   # randomly chosen ONCE per project, then never changed

BACKEND_PORT="${PORT_PREFIX}4"
FRONTEND_PORT="${PORT_PREFIX}2"

lsof -ti :$BACKEND_PORT | xargs kill -9 2>/dev/null
lsof -ti :$FRONTEND_PORT | xargs kill -9 2>/dev/null

# cd backend && npm start -- --port $BACKEND_PORT &
# cd frontend && npm start -- --port $FRONTEND_PORT &

echo "Backend:  http://localhost:$BACKEND_PORT"
echo "Frontend: http://localhost:$FRONTEND_PORT"
```

If the project uses nvm, bake the version switch into start.sh — see effortless-cli's "Node version" section for the snippet.

## See also

- `effortless-setup-postgres` — superset for Postgres projects (preflight + init-db + this).
- `effortless-cli` — `effortless -init`, `-login`, `-setAccountAPIKey`, install/update of the CLI binary itself.
- `effortless-pipeline` — `effortless.json` structure and transpiler installation paths.
- `effortless-orchestrator` — the ORCHESTRATION RULE about `/effortless-rulebook/` and the rest of the framing.
