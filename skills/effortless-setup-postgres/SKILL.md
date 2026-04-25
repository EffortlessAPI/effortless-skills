---
name: effortless-setup-postgres
description: >
  Use when setting up an Effortless project with a postgres database from an
  existing Airtable base. This is the FIRST thing to do in any Effortless
  project that targets postgres — it installs the pipeline, pulls the
  rulebook, generates SQL, and creates the database. Must be run before
  writing any application code.
---

# Effortless Setup: Postgres from Airtable

## TOKEN DISCIPLINE — READ THIS FIRST

This setup is **mechanical and atomic**. Run the commands, trust the output, move on.

**DO NOT:**
- Read generated SQL files (00-05) after the build
- Load additional skills to "understand" the generated schema
- Cat/read the rulebook JSON in full
- "Verify" by reading files back into context
- Run `effortless build` immediately after `effortless -install` — install already builds once.

**DO:**
- Run the commands below sequentially — they are deterministic
- After setup, query the rulebook with lightweight one-liners (see below)
- Trust that `vw_<tablename>` views exist with snake_case columns matching the Airtable fields

The pipeline produces `vw_*` views deterministically. If you need to confirm a column name, run:
`psql -d <dbname> -c "\d vw_<tablename>"`

---

## Prerequisites

- `effortless` CLI installed and logged in (`effortless -login`) — see `effortless-install-cli` skill
- Airtable API key configured (`effortless -setAccountAPIKey airtable=pat...`)
- PostgreSQL running locally

## 🚨🚨🚨 NEVER RUN `effortless airtable-to-rulebook` FROM THE PROJECT ROOT 🚨🚨🚨

The rulebook lives at **`/effortless-rulebook/effortless-rulebook.json`** — NOT at the project root.

If you find yourself typing `effortless airtable-to-rulebook` (or `effortless -install airtable-to-rulebook`) from the project root, **STOP**. You are about to dump `effortless-rulebook.json` into the wrong directory and register the transpiler with `RelativePath: /` — which will then poison every subsequent `effortless build`.

Always: `cd effortless-rulebook && effortless -install airtable-to-rulebook -account airtable -o effortless-rulebook.json && cd ..`

If you ever see `effortless-rulebook.json` at the project root, that is a bug — delete it, fix the transpiler entry in `effortless.json` (must be `RelativePath: /effortless-rulebook`), and redo the install from inside `/effortless-rulebook/`.

## 🚨 GOLDEN RULE — `cd` INTO THE TARGET FOLDER BEFORE `effortless -install`

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

## ⚠️ Known install-time annoyance — silent registration failure

Independent of the cwd rule above, `effortless -install rulebook-to-postgres` and `effortless -install -exec` sometimes finish with the error:

```
startIndex cannot be larger than length of string. (Parameter 'startIndex')
```

When this happens, the transpiler **does not get added to `effortless.json`** even though the files were written correctly. Workaround: append the transpiler entry to `effortless.json` by hand (see Steps 3 and 5 below). The `airtable-to-rulebook` install does not exhibit this — registration succeeds normally.

## 🛡️ BUILD DISCIPLINE — git-frame every `effortless build`

`effortless build` regenerates files under `effortless-rulebook/` and `postgres/` and **drops + re-inits** the local Postgres DB. Anything hand-edited inside those folders WILL be overwritten.

Therefore, every `effortless build` (including the very first one after setup) MUST be sandwiched in commits:

1. **Pre-build commit (clean tree required):**
   - Run `git status --porcelain`. If non-empty, **STOP** and ask the user for permission before continuing — do NOT silently overwrite their in-progress work. Offer to commit, stash, or abort.
   - Once clean, proceed.
2. **Run:** `effortless build`
3. **Post-build commit:** immediately `git add -A && git commit -m "effortless build: <one-line reason>"`. This guarantees the commit contains **only** what the build changed — making the build's effect easy to inspect, revert, or reapply.

This is non-negotiable. The agent must never run `effortless build` on a dirty tree without explicit user approval, and must always commit immediately after.

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

- `effortless-claude` — overview / entry point
- `effortless-setup-postgres` — initial setup (already run for this project)
- `effortless-workflow` — making changes (Airtable ↔ rulebook ↔ build)
- `effortless-leopold-loop` — CHANGE-RULE → REBUILD → CONSUME-VIEWS cycle
- `effortless-sql` — `vw_*` view / function patterns; never read base tables
- `effortless-query` — querying the rulebook JSON
- `effortless-conventions` — naming, FK, DAG rules
- `effortless-pipeline` — `effortless build` pipeline + `effortless.json`
- `effortless-cli` — CLI flags / commands
- `effortless-airtable` / `effortless-airtable-omni` — Airtable schema changes

## Build discipline (IMPORTANT — applies every time)

`effortless build` regenerates `effortless-rulebook/` and `postgres/` and
DROPS + re-inits the local Postgres DB. Hand-edits in those folders will
be lost.

Around every `effortless build`:

1. **Before:** working tree must be clean (`git status --porcelain` empty).
   If dirty, **ask the user for permission** before building — never silently
   overwrite work in progress.
2. **Run** `effortless build`.
3. **After:** immediately `git add -A && git commit -m "effortless build: <reason>"`
   so the commit captures only what the build changed. This makes a bad build
   trivial to revert and makes the build's effect easy to inspect in isolation.
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

## After Setup — Querying the Schema (Lightweight)

Do NOT read the generated SQL. Instead:

**Option A — psql (zero token cost):**
```bash
psql -d <dbname> -c "\d vw_<tablename>"
```

**Option B — Rulebook schema query (no data, minimal tokens):**
```bash
cat effortless-rulebook/effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for k,v in d.items():
  if isinstance(v,dict) and 'schema' in v:
    print(f'{k}:')
    for f in v['schema']:
      print(f'  {f[\"name\"]:30s} {f[\"type\"]:12s} {f[\"datatype\"]}')
"
```

## Common Issues

| Problem | Fix |
|---------|-----|
| `startIndex cannot be larger than length of string` during install | Silent registration failure (separate from cwd behavior — files were still written correctly). Append the transpiler entry to `effortless.json` by hand (see Steps 3 and 5). |
| Generated SQL files at project root after install | `-install` was run from the wrong cwd (likely from project root instead of from inside `/postgres/`). Delete the misplaced files at root and redo the install from inside `/postgres/`. See "GOLDEN RULE" section. |
| Only `airtable-to-rulebook` registered in `effortless.json` | Silent registration failure on `rulebook-to-postgres` install. Manually append the `rulebook-to-postgres` and `initdb` entries (see Steps 3 and 5). |
| `effortless: command not found` | See `effortless-install-cli` skill |
| `401 Unauthorized` | `effortless -setAccountAPIKey airtable=pat...` |
| `database does not exist` | `createdb <db-name>` first |
| Empty rulebook | Verify baseId, verify API key has access |
| `effortless.json not found` | Run `effortless -init` from project root |
