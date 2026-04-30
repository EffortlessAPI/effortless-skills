---
name: effortless-setup-postgres
description: >
  Use when setting up an Effortless project with a postgres database from an
  existing Airtable base. This is the FIRST thing to do in any Effortless
  project that targets postgres — it installs the pipeline, pulls the
  rulebook, generates SQL, and creates the database. Must be run before
  writing any application code.
audience: customer
---

# Effortless Setup: Postgres from Airtable

> **Token Discipline pointer.** The canonical rule lives in
> `effortless-orchestrator`: `effortless build` is atomic — run, commit,
> move on. Don't re-read generated SQL or the full rulebook to "verify"
> anything; query lightly with `psql -c "\d vw_<table>"` or the one-liners
> in `effortless-query`.

> Long-tail material — the per-OS preflight install guidance for missing
> tools, the Step 7 prototype-app + `start.sh` scaffolding, and the
> Common Issues troubleshooting table — lives in [REFERENCE.md](REFERENCE.md).
> The core flow (axiom, golden rules, Steps 0–6, verification) stays here.

---

## Base ID is the SSoT — derive everything else from the rulebook

If the user gives you only an Airtable **base id** (e.g. `appXXXXXXXX`) and nothing else, treat that base as the **single source of truth** for the project. Do NOT ask the user for a project name, table list, or description — pull the rulebook first, then derive everything you need from it.

**Order of operations when only a base id is given:**

1. Pick a **temporary working slug** (e.g. `_bootstrap`) and create `<my-projects>/_bootstrap/` so you have somewhere to run `effortless -init` and `airtable-to-rulebook`.
2. Run Steps 0–2 below inside that temp dir to get `effortless-rulebook/effortless-rulebook.json` populated.
3. Read the rulebook's `_meta` (or top-level base metadata) to extract:
   - **Base name** → slugify as `lowercased, [^a-z0-9]+ → "-"`, strip leading/trailing `-`. This is the **project slug**, and the directory should be **renamed** from `_bootstrap` to this slug.
   - **Base description** → goes into `README.md`.
   - **Table list + table descriptions** → `README.md` "Tables" section.
   - **Field list + field descriptions per table** → optional schema appendix in `README.md`, or skip if large.
4. **Write `README.md` at the project root before continuing** with Steps 3+ of the setup. The README should contain: base name, base id, base description, one-line-per-table summary (name + description). This is the agent's own grounding doc — future turns read it instead of re-querying Airtable.
5. Continue with Step 3 (`rulebook-to-postgres`) onward. The DB name should be the project slug (or `<slug>_db` if the slug collides with a postgres reserved word).

**Slugify rule (canonical):** `name.lower()` → replace any run of non-`[a-z0-9]` chars with `-` → strip leading/trailing `-`. Examples: `"My Cool Base!"` → `my-cool-base`; `"ACE-KPI / Amazon Ledger"` → `ace-kpi-amazon-ledger`.

`effortless airtable-to-rulebook` pulls base name, description, tables, descriptions, fields, and field descriptions in a single call — that one file fills every gap. There is no need to hit the Airtable meta API separately.

## Prerequisites

- `effortless` CLI installed and logged in (`effortless -login`) — see `effortless-install-cli` skill
- Airtable API key configured (`effortless -setAccountAPIKey airtable=pat...`)
- PostgreSQL running locally
- Docker (optional — only required if the user wants the containerized postgres path)

## Step −1: Preflight — verify local tools BEFORE running setup

Before Step 0, run the checks below. **For each missing tool, stop and ask the user how they want to proceed** — do NOT silently install system-level software. The per-OS install options live in [REFERENCE.md → Preflight install options](REFERENCE.md#preflight-install-options).

```bash
# Run these in parallel; report which are missing.
command -v effortless    >/dev/null 2>&1 && effortless -version 2>/dev/null || echo "MISSING: effortless"
command -v psql          >/dev/null 2>&1 && psql --version             || echo "MISSING: postgres (psql)"
command -v pg_isready    >/dev/null 2>&1 && pg_isready -h localhost    || echo "MISSING: postgres server not reachable on localhost:5432"
command -v docker        >/dev/null 2>&1 && docker --version           || echo "MISSING: docker (optional)"
command -v node          >/dev/null 2>&1 && node --version             || echo "MISSING: node (needed for Step 7 prototype app)"
command -v git           >/dev/null 2>&1 && git --version              || echo "MISSING: git"
```

**Do not proceed to Step 0 until the user has confirmed their choice for each missing tool and the checks above pass (or the user explicitly waived a non-blocking one like Node/Docker).**

---

## NEVER RUN `effortless airtable-to-rulebook` FROM THE PROJECT ROOT

The rulebook lives at **`/effortless-rulebook/effortless-rulebook.json`** — NOT at the project root.

If you find yourself typing `effortless airtable-to-rulebook` (or `effortless -install airtable-to-rulebook`) from the project root, **STOP**. You are about to dump `effortless-rulebook.json` into the wrong directory and register the transpiler with `RelativePath: /` — which will then poison every subsequent `effortless build`.

Always: `cd effortless-rulebook && effortless -install airtable-to-rulebook -account airtable -o effortless-rulebook.json && cd ..`

If you ever see `effortless-rulebook.json` at the project root, that is a bug — delete it, fix the transpiler entry in `effortless.json` (must be `RelativePath: /effortless-rulebook`), and redo the install from inside `/effortless-rulebook/`.

## GOLDEN RULE — `cd` INTO THE TARGET FOLDER BEFORE `effortless -install`

`effortless -install` is **cwd-sensitive**. It writes the transpiler's initial output to whatever directory you run it from, and registers the transpiler in `effortless.json` with that directory as `RelativePath`. Subsequent `effortless build` runs each transpiler from its registered `RelativePath`.

**Therefore:** before installing any transpiler, `cd` into the directory where you want its output. This applies to **every** `-install`, including the one that already worked in Step 2:

```bash
# CORRECT — cd into target folder first
mkdir -p postgres && cd postgres
effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json
cd ..

# WRONG — running from project root dumps SQL into project root
effortless -install rulebook-to-postgres -i ./effortless-rulebook/effortless-rulebook.json
```

If you ever see SQL artifacts (`0*.sql`, `init-db.sh`, `function-overrides/`, etc.) at the project root, the cause is almost always that `-install` was run from the wrong cwd. The fix is to redo the install from inside `/postgres/`, not to keep moving files by hand.

## Known install-time annoyance — silent registration failure

Independent of the cwd rule above, `effortless -install rulebook-to-postgres` and `effortless -install -exec` sometimes finish with the error:

```
startIndex cannot be larger than length of string. (Parameter 'startIndex')
```

When this happens, the transpiler **does not get added to `effortless.json`** even though the files were written correctly. Workaround: append the transpiler entry to `effortless.json` by hand (see Steps 3 and 5). The `airtable-to-rulebook` install does not exhibit this — registration succeeds normally.

## BUILD DISCIPLINE — the BRIGHT RED LINE between rulebook and hand-written code

`effortless build` regenerates files under `effortless-rulebook/` and `postgres/` and **drops + re-inits** the local Postgres DB. Anything hand-edited inside those folders WILL be overwritten.

The point of git-framing every build is to draw a **bright red line** in history between **ontology changes** (anything that flows from Airtable → rulebook → generated SQL) and **hand-written code** (app, scripts, customizations). One commit per build, containing **only** generated output, makes that line legible to humans, agents, and `git blame` forever.

Every `effortless build` — INCLUDING the very first one immediately after setup — MUST be sandwiched as follows:

1. **Pre-build: clean tree required.**
   - Run `git status --porcelain`. If non-empty, **STOP** and ask the user before continuing — do NOT silently overwrite in-progress work. Offer to commit, stash, or abort.
   - Once clean, proceed.
2. **Run:** `effortless build`.
3. **Post-build commit — IMMEDIATELY, BEFORE writing or modifying ANY other code.**
   - `git add -A && git commit -m "effortless build: <one-line reason>"`.
   - Do NOT scaffold the app, edit `package.json`, write `start.sh`, edit any application code, or run any other tool between the build and this commit. The commit must contain **only** what the build produced.
   - This is the bright red line. Crossing it (mixing build output with hand-written code in one commit) destroys the ability to tell rulebook-driven changes apart from manual ones, and makes bad builds painful to revert.

This is non-negotiable. The agent must never run `effortless build` on a dirty tree without explicit user approval, and must always commit the build output as its own commit before doing anything else.

## Setup — Run These Commands IN ORDER

From the project root (`<PROJECT_ROOT>` below):

### Step 0: Make it a git repo + drop in CLAUDE.md

```bash
cd <PROJECT_ROOT>
git init -q

# .gitignore — keep generated DB dumps and node_modules out of git
cat > .gitignore <<'EOF'
node_modules/
.env
*.log
.DS_Store
# Intermediate build artifacts from the ssotme:// protocol
/.ssotme/**/*.zfs
EOF

# CLAUDE.md — tells future Claude sessions this is an Effortless project
# and which skills to load. ALSO encodes the build-discipline rule above.
cat > CLAUDE.md <<'EOF'
# Project Conventions

This is an **Effortless Rulebook (ERB)** project. Schema lives in Airtable
(see `baseId` in `effortless.json`) and is pulled into
`effortless-rulebook/effortless-rulebook.json`, then generated into Postgres
SQL under `postgres/` and loaded into a local Postgres DB by `init-db.sh`.

When working in this project, load the relevant `effortless-*` skills:

- `effortless-orchestrator` — overview / entry point
- `effortless-setup-postgres` — initial setup (already run for this project)
- `effortless-workflow` — making changes (Airtable ↔ rulebook ↔ build)
- `effortless-leopold-loop` — CHANGE-RULE → REBUILD → CONSUME-VIEWS cycle
- `effortless-sql` — `vw_*` view / function patterns; never read base tables
- `effortless-query` — querying the rulebook JSON
- `effortless-conventions` — naming, FK, DAG rules
- `effortless-pipeline` — `effortless build` pipeline + `effortless.json`
- `effortless-cli` — CLI flags / commands
- `effortless-airtable` / `effortless-airtable-omni` — Airtable schema changes

## Build discipline — THE BRIGHT RED LINE (applies every time)

`effortless build` regenerates `effortless-rulebook/` and `postgres/` and
DROPS + re-inits the local Postgres DB. Hand-edits in those folders will
be lost.

Every build draws a **bright red line** in git history between **ontology
changes** (Airtable → rulebook → generated SQL) and **hand-written code**
(app, scripts, customizations). The discipline below keeps that line clean.

Around every `effortless build`:

1. **Before:** working tree MUST be clean (`git status --porcelain` empty).
   If dirty, **ask the user for permission** before building — never silently
   overwrite work in progress.
2. **Run** `effortless build`.
3. **Immediately after — BEFORE writing ANY other code, scaffolding the app,
   editing `package.json`, or running any other tool:**
   `git add -A && git commit -m "effortless build: <reason>"`.
   The build commit must contain **only** generated output. Mixing build
   output with hand-written code in a single commit erases the red line and
   makes bad builds painful to revert. Do not cross the line.
EOF

git add CLAUDE.md .gitignore
git commit -q -m "chore: bootstrap effortless project (CLAUDE.md + .gitignore)"
```

### Step 1: Init project + record baseId

```bash
cd <PROJECT_ROOT>
effortless -init
effortless -addSetting baseId=<BASE_ID>
git add -A && git commit -q -m "chore: effortless -init (baseId=<BASE_ID>)"
```

### Step 2: Install airtable-to-rulebook (this one works)

```bash
mkdir -p effortless-rulebook && cd effortless-rulebook
effortless -install airtable-to-rulebook -account airtable -o effortless-rulebook.json
cd ..
```

Verify: `effortless-rulebook/effortless-rulebook.json` exists, and `effortless.json` has a `RelativePath: /effortless-rulebook` entry.

### Step 3: Install rulebook-to-postgres

`cd` into `/postgres/` first (see "GOLDEN RULE" above) so the SQL artifacts land there:

```bash
mkdir -p postgres && cd postgres
effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json
cd ..
```

Verify: `postgres/00-bootstrap.sql` (and the rest of the `0*.sql` set, plus `init-db.sh` and `function-overrides/`) exists, and `effortless.json` has a `RelativePath: /postgres` entry for `rulebooktopostgres`.

If the install printed a `startIndex cannot be larger than length of string` error and `effortless.json` is missing the `rulebooktopostgres` entry, append it by hand (this is the "silent registration failure" called out earlier):

```json
{
  "IsSSoTTranspiler": false,
  "Name": "rulebooktopostgres",
  "RelativePath": "/postgres",
  "CommandLine": "rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json",
  "IsDisabled": false,
  "PinnedVersion": "v2026.04.23.1316"
}
```

(Pin whatever version the install printed at the top of its output.)

### Step 4: Configure DB name and run init

Edit `postgres/init-db.sh` → set `DEFAULT_CONN`:

```bash
DEFAULT_CONN="postgresql://postgres@localhost:5432/<your-db-name>"
```

Then create the DB and run init:

```bash
createdb <your-db-name>
cd postgres && chmod +x init-db.sh && ./init-db.sh && cd ..
```

### Step 5: Register init-db.sh as a build step

Try registering `init-db.sh` as an `-exec` step from inside `/postgres/`:

```bash
cd postgres
effortless -install -exec ./init-db.sh
cd ..
```

If that prints the `startIndex` registration error, fall back to adding the entry to `effortless.json` by hand so future `effortless build` runs init-db.sh as part of the full pipeline.

**How `-exec` entries work — read this before guessing the `CommandLine` value.** The `CommandLine` field is the literal argument string passed to the effortless build engine. For exec steps, that string is `-exec <command>`, where `<command>` is invoked from the transpiler's `RelativePath`. The runtime itself is the shell — you do NOT prepend `bash`, `sh`, or `cmd`. Correct: `"-exec ./init-db.sh"`. WRONG: `"exec bash init-db.sh"`, `"bash init-db.sh"`, `"./init-db.sh"`.

```json
{
  "IsSSoTTranspiler": false,
  "Name": "initdb",
  "RelativePath": "/postgres",
  "CommandLine": "-exec ./init-db.sh",
  "IsDisabled": false,
  "PinnedVersion": ""
}
```

After Step 5, `effortless build` from the project root will:
1. Re-pull the rulebook from Airtable into `/effortless-rulebook/effortless-rulebook.json`
2. Re-generate SQL into `/postgres/` (RelativePath is honored at build time)
3. Drop and re-init the database via `init-db.sh`

### Step 6: Commit the bootstrap output

Setup wrote a lot of generated files. Commit them now so the very next `effortless build` (per **BUILD DISCIPLINE** above) starts from a clean tree:

```bash
cd <PROJECT_ROOT>
git add -A
git commit -q -m "chore: effortless setup-postgres bootstrap (rulebook + SQL + init-db)"
```

From here on, every `effortless build` MUST be sandwiched in commits per the BUILD DISCIPLINE section at the top of this skill.

## Verifying the install (one-shot, lightweight)

```bash
cat <PROJECT_ROOT>/effortless.json | python3 -c "
import sys,json
d=json.load(sys.stdin)
for t in d.get('ProjectTranspilers',[]):
  print(f\"{t['RelativePath']:30s} {t['CommandLine']}\")"
```

You should see THREE entries: `/effortless-rulebook` (airtable-to-rulebook), `/postgres` (rulebook-to-postgres), `/postgres` (init-db.sh exec). Confirm DB views exist:

```bash
psql -d <dbname> -c "\dv vw_*"
```

## Step 7: Scaffold the prototype app + `./start.sh`

Once the DB is initialized, scaffold a **minimal Node prototype app** and a `start.sh` that boots it on a deterministic port pair. The contract, defaults, and full skeleton live in [REFERENCE.md → Step 7 prototype app](REFERENCE.md#step-7--scaffold-the-prototype-app--startsh) — load that section when you're ready to do this step. Do NOT inline a UI framework / design system without the user asking.

## After Setup — Querying the Schema (Lightweight)

Do NOT read the generated SQL. Instead:

**Option A — psql (zero token cost):**
```bash
psql -d <dbname> -c "\d vw_<tablename>"
```

**Option B — Rulebook schema query (no data, minimal tokens):** see `effortless-query` skill.

## Common Issues

A full troubleshooting table (silent registration failures, misplaced SQL,
401s, missing `effortless.json`, etc.) lives in
[REFERENCE.md → Common Issues](REFERENCE.md#common-issues). Load it when
something goes sideways.

---

## See also

- `effortless-orchestrator` — for the canonical Token Discipline + the bigger mental model.
- `effortless-install-cli` — for installing the `effortless` CLI binary if it's missing in preflight.
- `effortless-cli` / `effortless-pipeline` — for the install / build commands this skill drives.
- `effortless-leopold-loop` — for the iterative cycle once setup is done.
- `effortless-bases` — switch to this skill instead if the Postgres database is hosted on `bases.effortlessapi.com`.
- [REFERENCE.md](REFERENCE.md) — long-tail content (preflight install options per OS, Step 7 prototype-app skeleton, Common Issues troubleshooting).
