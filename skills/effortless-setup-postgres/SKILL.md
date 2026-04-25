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

**DO:**
- Run the commands below sequentially — they are deterministic
- After setup, query the rulebook with lightweight one-liners (see below)
- Trust that `vw_<tablename>` views exist with snake_case columns matching the Airtable fields

The pipeline produces `vw_*` views deterministically. You already know what's in them
from the specification. If you need to confirm a column name, run:
`psql -d <dbname> -c "\d vw_<tablename>"`

---

## Prerequisites

- `effortless` CLI installed and logged in (`effortless -login`)
- Airtable API key configured (`effortless -setAccountAPIKey airtable=pat...`)
- PostgreSQL running locally
- A target database already created (e.g. `createdb my-db-name`)

## Setup — Run These Commands IN ORDER

From the project root:

```bash
# Step 1: Initialize
effortless init
effortless -addSetting baseId=<BASE_ID>

# Step 2: Pull rulebook from Airtable
mkdir -p effortless-rulebook && cd effortless-rulebook
effortless -install airtable-to-rulebook -p baseId=<BASE_ID> -account airtable -o effortless-rulebook.json
effortless build

# Step 3: Generate SQL from rulebook
mkdir -p ../postgres && cd ../postgres
effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json
effortless build

# Step 4: Fix DB name and initialize
# Edit postgres/init-db.sh → set DB_NAME="<your-db-name>"
chmod +x init-db.sh && ./init-db.sh
```

**That's it. Move to application code now.**

## After Setup — Querying the Schema (Lightweight)

Do NOT read the generated SQL. Instead, use ONE of these lightweight approaches:

**Option A — psql (preferred, zero token cost):**
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

This gives you all table names and field names in ~20 lines of output.
That's all you need to write application code.

## Rebuilding (Also Atomic)

```bash
effortless build && cd postgres && ./init-db.sh
```

No reading. No verifying. Trust the pipeline.

## Common Issues

| Problem | Fix |
|---------|-----|
| `effortless: command not found` | `npm i -g ssotme` or check PATH |
| `401 Unauthorized` | `effortless -setAccountAPIKey airtable=pat...` |
| `database does not exist` | `createdb <db-name>` first |
| Empty rulebook | Verify baseId, verify API key has access |
| `effortless.json not found` | Run `effortless init` from project root |
