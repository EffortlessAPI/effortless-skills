---
name: effortless-claude
description: >
  Use when working with Effortless Rulebook (ERB) projects — Airtable-sourced
  schema-first business rules, `effortless.json` or the legacy `ssotme.json` build pipelines, effortless-rulebook.json
  ontologies, rulebook-to-postgres code generation, or any project containing an
  effortless-rulebook/ directory or effortless.json or ssotme.json file.
  Also use when the user says "update effortless claude", "update your effortless skills",
  "update effortless skills", "reinstall effortless", "refresh skills", or any variant
  asking to update or reinstall the effortless skill set.
---

# Effortless Rulebook (ERB) — Orchestrator

This is the top-level skill for ERB projects. It provides the mental model and routes to specialized sub-skills.

## The ERB Mental Model

```
                    AIRTABLE SSoT <-- The formal editing surface for ontology. UI for agents both human and AI
                         |
                    airtable-to-rulebook <-- effortless tool
                         |
                         v
              effortless-rulebook.json  <-- PROJECTION OF THE SINGLE SOURCE OF TRUTH
              /    |    |    |    \
             /     |    |    |     \
            v      v    v    v      v
        Postgres  Go  Python XLSX  OWL ...  (execution substrates)
            |
        views.vw_*  <-- ALWAYS READ FROM THESE
        tables.*    <-- ALWAYS WRITE TO THESE
```

## The Leopold Loop

The **Leopold loop** is the user's name for the iterative ERB development cycle: CHANGE RULE (in Airtable) → `effortless build` → CONSUME the generated views in app code → repeat. It is the core workflow that makes ERB feel effortless.

**When the user mentions "the loop", "Leopold loop", "do a turn", "rebuild the rulebook", or any variant — load the `effortless-leopold-loop` skill.** That skill contains the full diagram, the trigger phrases, the step-by-step expectations, and the anti-patterns. Do not try to reason about the loop from this orchestrator alone.

## 🚨 ORCHESTRATION RULE — `effortless-rulebook.json` LIVES IN `/effortless-rulebook/` 🚨

The rulebook file path is **always** `/effortless-rulebook/effortless-rulebook.json`. It is NEVER at the project root.

Before running ANY `effortless airtable-to-rulebook` or `effortless -install airtable-to-rulebook` command, you MUST `cd effortless-rulebook` first. Running it from the project root dumps the rulebook into the wrong place AND registers the transpiler with the wrong `RelativePath` in `effortless.json`, which then poisons every subsequent `effortless build`.

If `effortless-rulebook.json` ever appears at the project root: that is a bug — delete it, fix `effortless.json` so the airtable-to-rulebook entry has `RelativePath: /effortless-rulebook`, then redo the install from inside `/effortless-rulebook/`. See `effortless-setup-postgres` for details.

## Critical Guardrails

1. **Query the rulebook FIRST — NEVER read generated files** — The JSON has everything.
   **Actually QUERY** — root nodes are entity names with "schema" and "data" sub-properties.
   The schema has the fields/lookups/rollups/formulas (excel dialect).
   **QUERY for TABLES first** — then query for the fields from JUST those tables, rather
   than ever reading the full file. The full file (with data) could be MB's. QUERY IT!
   **NEVER read generated SQL files (00-05)** — they are a projection of the rulebook.
   If you need to know what columns a view has, query the rulebook schema or run
   `psql -c "\d vw_tablename"`. Do NOT cat/read the SQL files into your context.
2. **NEVER edit generated files** — Files `00`-`05` in `postgres/` are overwritten on every build.
   **ONLY** update `00b`-`05b` files AFTER the original airtable has been updated first.
   **ONLY if OMNI can't fix the tool's default 02 functions (for example) - THEN we can override it with a fallback 02b function.  But ONLY after exhausting the actual SSoT (airtable) first.
3. **Always read from `vw_*` views**, never base tables.
   **Always WRITE to tables directly**
4. **Always ask permission** before modifying the json rulebook directly.
5. **Usually `effortless build` is the final step**, except in the rare cases where we have modified the json rulebook directly, and are explicitly trying to move that data FROM the rulebook INTO airtable. In that case, an effortless build would overwrite the currently HEAD json.

## Token Discipline — Pipeline Operations Are Atomic

**`effortless build` is a zero-context operation.** It does not produce output you need
to read. It regenerates files deterministically from the rulebook. The correct pattern:

```
Determine something changed → `effortless build` → commit → DONE
```

Do NOT:
- Read generated files after a build to "verify" or "understand" them
- Load skills to interpret build output
- Cat SQL files into your context window
- Read the rulebook.json in full (it can be megabytes)

After a build, you already know the schema because you queried it BEFORE the build.
The generated files are just a mechanical projection — trust the pipeline.

**Context-window rule:** If you need schema info, use lightweight targeted queries
(see `effortless-query` skill) that extract ONLY the table/field metadata you need.
Never load the full rulebook or full SQL files. A 5-line python one-liner that extracts
table names + field names is worth 1000x more than reading the whole file.

## Initializing an Effortless Project

When the user says "make this an effortless project", "initialize effortless", "init effortless project", or similar:

### Step 1: Initialize the CLI project
```bash
effortless -init -projectName "Project Name"
```
This creates `effortless.json` in the project root.

### Step 2: Ensure the user is logged in
```bash
effortless -info    # check login status
effortless -login   # if not logged in — interactive email + 6-digit code flow
```

### Step 3: Create the directory structure
```
project-root/
  effortless.json
  CLAUDE.md
  start.sh
  bootstrap/           # raw-text-to-rulebook output
  effortless-rulebook/  # airtable-to-rulebook output
    push-to-airtable/   # reverse sync (disabled by default)
  postgres/             # rulebook-to-postgres output
  docs/                 # rulebook-to-docs output
```

### Step 4: Install transpilers (from their respective directories)
See `effortless-cli` and `effortless-pipeline` skills for exact install commands. Each tool MUST be installed from the directory where its output is expected.

### Step 5: Create CLAUDE.md (see below)

### Step 6: Create start.sh (see below)

## Connecting the Rulebook to Airtable

When the user says "connect to Airtable", "hook up Airtable", "link the rulebook to Airtable", or similar:

1. **Ensure API key is set:**
   ```bash
   effortless -setAccountAPIKey airtable=patXXXXXXXX.XXXXXXXX
   ```
   Or check if it already exists in `~/.ssotme/ssotme.key`.

2. **Set the base ID** in `effortless.json` as a project setting (`baseId`).

3. **Install airtable-to-rulebook** from `/effortless-rulebook/`:
   ```bash
   cd effortless-rulebook/
   effortless -install airtable-to-rulebook -o effortless-rulebook.json -account airtable
   ```

4. **Install rulebook-to-airtable** (DISABLED) from `/effortless-rulebook/push-to-airtable/`:
   ```bash
   cd effortless-rulebook/push-to-airtable/
   effortless -install rulebook-to-airtable -i ../effortless-rulebook.json -account airtable
   ```
   Mark as `"IsDisabled": true` — this is only for reverse sync with `-id`.

5. **Run the first build** to pull from Airtable:
   ```bash
   effortless build
   ```

## start.sh — Project Launcher

Every effortless project gets a `start.sh` in the root that:
1. Picks a random 3-digit prefix `nnn` (consistent per project, chosen once)
2. Stops any processes running on port `nnn4` (backend) and `nnn2` (frontend)
3. Restarts the backend on port `nnn4` and frontend on port `nnn2`
4. Is idempotent — running `./start.sh` always results in a clean restart

```bash
#!/bin/bash
# Start the project services
PORT_PREFIX=847  # randomly chosen per project

BACKEND_PORT="${PORT_PREFIX}4"
FRONTEND_PORT="${PORT_PREFIX}2"

# Stop existing processes
lsof -ti :$BACKEND_PORT | xargs kill -9 2>/dev/null
lsof -ti :$FRONTEND_PORT | xargs kill -9 2>/dev/null

# Start backend and frontend (customize per project)
# cd backend && npm start -- --port $BACKEND_PORT &
# cd frontend && npm start -- --port $FRONTEND_PORT &

echo "Backend: http://localhost:$BACKEND_PORT"
echo "Frontend: http://localhost:$FRONTEND_PORT"
```

## When You Need More Detail

This orchestrator provides the big picture. For specifics, the following companion skills are available — Claude Code will load them automatically based on what you're doing:

| Skill | When to Use |
|-------|-------------|
| `effortless-install-cli` | Installing/updating the `effortless` CLI itself — clones the repo and registers it as a global npm package. Triggered by "install effortless", "the cli isn't installed", `effortless: command not found`. |
| `effortless-cli` | CLI commands — login, init, install, build, API keys, project settings |
| `effortless-setup-postgres` | First-run setup of an ERB project that targets Postgres — installs the pipeline, pulls the rulebook, generates SQL, creates the local DB. Run BEFORE writing any application code. |
| `effortless-bootstrap` | Bootstrapping from raw text — the Shadle steps from vocabulary to rulebook to Airtable |
| `effortless-leopold-loop` | The iterative ERB dev cycle — triggered by "the loop", "Leopold loop", "do a turn", "rebuild the rulebook", etc. |
| `effortless-query` | Querying the rulebook JSON — listing tables, extracting schema, finding relationships, inspecting formulas |
| `effortless-schema` | Understanding the JSON structure — field types, datatypes, formula syntax, `_meta` section |
| `effortless-conventions` | Naming rules, DAG structure, PK/FK patterns, no many-to-many |
| `effortless-workflow` | Making changes — Path A (Airtable-first) vs Path B (Rulebook-first), permission checkpoints |
| `effortless-pipeline` | Build system — `effortless.json` or the legacy `ssotme.json`, transpilers, `effortless build`, installation |
| `effortless-sql` | Generated SQL — views vs tables, `00`-`05` files, `*b-customize-*` files, SQL patterns |
| `effortless-airtable` | Airtable API — adding scalar fields, creating/modifying records, field renaming — anything the REST API supports |
| `effortless-airtable-omni` | Non-scalar schema changes via Playwright + OMNI — formula fields, lookup fields, rollup fields, and new table creation (requires the Name formula). Drives a headed Chrome browser automatically. |
| `effortless-diagnostics` | Diagnostic queries, DAG validation, legacy code migration |
| `effortless-bases` | Spin up a Postgres base on bases.effortlessapi.com and secure it end-to-end with magic-links auth + RLS — the "create a base + magic-links tenant + RLS-secured app in 5 minutes" flow. |
| `magic-links` | Add passwordless email-code (magic-link) auth to ANY Postgres-backed project (not just bases.effortlessapi.com). Mints a tenant on magiclink.effortlessapi.com, wires `Authorization: Bearer` middleware, installs the `app.jwt_*()` SQL helpers for RLS. |

## Schema Change Decision Tree

When making Airtable schema changes, follow this decision tree:

```
Is this a NEW BUSINESS ENTITY (anything that looks like a domain "table" —
users, roles, products, orders, profiles)?
  YES → Airtable. Always. No exceptions for "just for auth" or "just a
        small lookup table." New table needs OMNI (Name formula).
        Then `effortless build`.
  NO  → ↓ continue with the existing tree

Is it a scalar field (text, number, select, checkbox, date, FK link, etc.)?
  YES → Use the Airtable REST API directly (effortless-airtable skill)
  NO  → Is it a formula, lookup, or rollup?
    YES → Use OMNI via Playwright (effortless-airtable-omni skill)
          Run: node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs <baseId> '<prompt>'
    
Is it a new table?
  YES → Use OMNI — every table needs a Name formula: SUBSTITUTE(LOWER({Label}), " ", "-")
        Create scalar fields + FKs via API first, then add Name formula via OMNI

Is it a CRUD operation (create/read/update/delete records)?
  YES → Always use the Airtable REST API directly
```

**Never generate OMNI prompts for the user to paste manually.** Instead, drive OMNI directly using the bundled `omni-send.mjs` Playwright script. This avoids wasting the user's time as a copy-paste middleman.

## Project CLAUDE.md Bootstrap

When you first encounter an ERB project that lacks a `CLAUDE.md`, or when initializing a new effortless project, **create one** in the project root. This ensures every future conversation (any user, any session) automatically knows the project's nature and key behaviors without the user having to explain. **This is critical — without it, subsequent Claude sessions will not follow the effortless methodology and will constantly break the process.**

Write a `CLAUDE.md` containing at minimum:

```markdown
# Project: {ProjectName}

This is an Effortless Rulebook (ERB) project. All development follows the effortless methodology.

## CRITICAL RULES — Read Before Doing Anything
1. **Airtable is the Single Source of Truth** — all schema changes go through Airtable first, then `effortless build`.
2. **NEVER edit generated files** — files 00-05 in postgres/ are regenerated on every build.
3. **Always read from vw_* views**, never base tables. Always WRITE to base tables directly.
4. **Query the rulebook FIRST** — `effortless-rulebook/effortless-rulebook.json` has everything. Don't grep generated code.
5. **Ask permission** before modifying the rulebook, Airtable, or running effortless build.
6. **Always run `effortless build`** after any Airtable schema or data change.
7. **Never reimplement business logic** in app code — consume calculated fields from views as opaque truth.

## Airtable Base
- Base ID: {baseId from effortless.json}
- API Key: stored in ~/.ssotme/ssotme.key (set via `effortless -setAccountAPIKey airtable=...`)
- Use the Airtable REST API for scalar field changes and all CRUD operations.
- Use OMNI (via Playwright) for formula, lookup, and rollup fields:
  `node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs {baseId} '<prompt>'`
- First-time OMNI use requires login: `node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs {baseId} --login`

## The Leopold Loop
The development cycle is: CHANGE RULE (in Airtable) -> `effortless build` -> CONSUME generated views in app code -> repeat.
When told to "do a turn of the loop" or "rebuild", load the effortless-leopold-loop skill.

## Build & Start
- Build: `effortless build` from project root
- Start: `./start.sh` from project root

## ERB Skills
All conventions live in the effortless-* skills (not in memory files):
effortless-claude, effortless-install-cli, effortless-cli, effortless-setup-postgres,
effortless-bootstrap, effortless-conventions, effortless-schema, effortless-query,
effortless-sql, effortless-pipeline, effortless-workflow, effortless-airtable,
effortless-airtable-omni, effortless-leopold-loop, effortless-diagnostics,
effortless-bases, magic-links.
```

Fill in `{ProjectName}` and `{baseId}` from the project's `effortless.json` (or legacy `ssotme.json`). Add any project-specific notes (e.g., which tables are most active, known quirks, deployment targets).

This ensures the skills ARE the single source of truth for project behavior, not scattered memory entries.

## Updating Effortless Claude Skills

When the user says "update effortless claude", "update your effortless skills", "reinstall effortless skills", or similar:

### Where the Skills Live

| Location | Role |
|----------|------|
| `effortless-claude/skills/` | **SSoT** — the source repo where all skill edits happen |
| `~/.claude/skills/effortless-*` | **Installed copies** — what Claude Code actually loads at runtime |

**NEVER edit the installed copies directly.** Always edit in `effortless-claude/skills/` first, then install.

### How to Update

1. **Pull the latest from the SSoT repo:**
   ```bash
   cd <path-to-effortless-claude>
   git pull
   ```

2. **Run the installer:**
   ```bash
   bash install.sh --yes
   ```
   This copies all skill folders from `skills/` into `~/.claude/skills/`, overwriting the installed versions. It also cleans up any deprecated skills.

3. **Verify** — list installed skills:
   ```bash
   ls ~/.claude/skills/effortless-*
   ```

### Install Modes

```bash
bash install.sh              # Interactive — asks before overwriting each skill
bash install.sh --yes        # Non-interactive — overwrite all without asking
bash install.sh --symlink    # Symlink instead of copy (for contributors/dev)
bash install.sh --uninstall  # Remove all installed effortless-* skills
```

### Adding a New Skill

1. Create a new directory under `effortless-claude/skills/`:
   ```
   skills/effortless-myskill/SKILL.md
   ```

2. The SKILL.md must have YAML frontmatter:
   ```yaml
   ---
   name: effortless-myskill
   description: >
     Use when ... (this text controls when Claude loads the skill —
     make it specific about trigger conditions)
   ---
   ```

3. Run `bash install.sh --yes` to install it.

The installer dynamically discovers all `skills/*/` directories — no need to register new skills anywhere.

### Editing an Existing Skill

1. Edit the file in `effortless-claude/skills/<skill-name>/SKILL.md`
2. Run `bash install.sh --yes` (or use `--symlink` mode to skip this step)
3. The next Claude Code conversation will pick up the changes

### The `description` Field Matters

The `description` in the YAML frontmatter is what Claude Code uses to decide when to load a skill. Write it as a trigger specification:
- Include the exact phrases users will say
- Include the file/directory names that indicate relevance
- Be specific — vague descriptions cause skills to load when they shouldn't (or not load when they should)

## Quick Reference

- **Tables**: PascalCase, plural (`Customers`, `WorkflowSteps`)
- **`Name` is ALWAYS the first field** — a formula compound key, the logical primary key
- **No `{Entity}Id` fields** — surrogate keys are managed by the substrate off-screen
- **Foreign Keys**: Singular entity name, no "Id" suffix (`Order.Customer`)
- **Reverse FKs**: Plural (`Customer.Orders`)
- **It's a DAG**: 1-to-many only, no cycles, no many-to-many
- **Every field** has a `Description`
- **Schema is small, data is big** — extract schema to save tokens, and query for root entities (other than the name/description and meta data - these are all tables).  They can be queried as {"Widgets":{"schema":[{fields}, {}...], "data":[{data},{...}, ...], other meta-data...}.  You can use json query to not grep or ever have to read/process the whole thing.
- **Two change paths**: Airtable-first (preferred) or Rulebook-first with reverse sync
- **`effortless build`** from root runs enabled transpilers; `-id` includes disabled ones
- **`effortless.json` or the legacy `ssotme.json`** defines the build pipeline