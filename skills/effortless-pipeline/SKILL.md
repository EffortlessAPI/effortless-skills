---
name: effortless-pipeline
description: >
  Use when working with the ERB build pipeline — ssotme.json configuration,
  transpiler catalog, effortless build commands, the -id flag, transpiler
  installation, or understanding how the build flows from Airtable through
  to generated code.
---

# The ssotme.json Build Pipeline

## Structure

```json
{
  "Name": "Project Name",
  "Description": "Optional description",
  "ProjectSettings": [
    { "Name": "baseId", "Value": "appXXXXXXXXXXXX" },
    { "Name": "project-name", "Value": "my-project" },
    { "Name": "_apikey_", "Value": "patXXX...XXX" }
  ],
  "ProjectTranspilers": [
    {
      "Name": "airtabletorulebook",
      "RelativePath": "/effortless-rulebook",
      "CommandLine": "airtable-to-rulebook -o effortless-rulebook.json -account airtable",
      "IsDisabled": false
    }
  ]
}
```

## Key Transpilers

| Transpiler | Direction | What It Does |
|------------|-----------|-------------|
| `airtable-to-rulebook` | Airtable -> JSON | Pulls schema + data from Airtable base into `effortless-rulebook.json` |
| `rulebook-to-postgres` | JSON -> SQL | Generates all `00`-`05` SQL files from the rulebook |
| `rulebook-to-airtable` | JSON -> Airtable | Pushes rulebook back to an Airtable base (reverse sync) |
| `init-db` | SQL -> Postgres | Runs `init-db.sh` to bootstrap the database |
| `json-hbars-transform` | JSON + Handlebars -> Docs | Generates documentation (README.SCHEMA.md etc.) |
| `rulebook-to-xlsx` | JSON -> Excel | Generates spreadsheet export |
| `airtable-to-odxml` | Airtable -> ODXML | Generates XML metadata for .NET |
| `odxml-to-csharp-pocos` | ODXML -> C# | Generates Entity Framework classes |

## Finding the Base ID and API Key

1. **Base ID**: Check `effortless.json` (or legacy `ssotme.json`) -> `ProjectSettings` -> `baseId`. This is the canonical location — all airtable-facing tools read it from here.
2. **API Key**: Priority order:
   - `AIRTABLE_API_KEY` environment variable
   - `~/.ssotme/ssotme.key` -> `APIKeys.airtable` (set via `effortless -setAccountAPIKey airtable=...`)
   - `effortless.json` (or `ssotme.json`) -> `ProjectSettings` -> `_apikey_`
3. **Setting the API Key**: `effortless -setAccountAPIKey airtable=patXXXXXXXX.XXXXXXXX`

## Running a Build

```bash
effortless build       # Runs all enabled transpilers in order (from project root)
effortless build -id   # Runs ALL transpilers, INCLUDING disabled ones
```

### Builds Are Atomic — Zero Context Cost

**`effortless build` is a fire-and-forget operation.** It deterministically regenerates
files from the rulebook. After running it:

- Do NOT read the generated files to "verify" or "understand" them
- Do NOT load skills to interpret build output
- Do NOT cat SQL files into your context window
- **Always commit immediately after the build** — `git add -A && git commit -m "effortless build: <reason>"`.
  This captures the exact diff on `effortless-rulebook.json` and all generated files.
  The diff from this commit (`git diff HEAD~1 -- effortless-rulebook/effortless-rulebook.json`)
  is the highest-fidelity source of truth for what changed in the schema.
- Then proceed to use the views in app code

The correct mental model: `effortless build` is like `npm install` — you run it and
trust that it worked. You don't read `node_modules/` afterwards.

If you need schema information AFTER a build, query the rulebook with a targeted
one-liner (see `effortless-query`) or run `psql -c "\d vw_tablename"`.

---

- **From project root**: `effortless build` reads `ssotme.json` and runs each enabled transpiler in its `RelativePath` directory. Disabled transpilers (`"IsDisabled": true`) are skipped.
- **From a subfolder**: `effortless build` can also be run from any subfolder that contains its own `ssotme.json` or is referenced as a `RelativePath`. This is how you run a specific transpiler in isolation.
- **The `-id` flag** (include disabled): Forces execution of all transpilers, even those marked `"IsDisabled": true`. This is essential for the reverse-sync workflow (Path B), where `rulebook-to-airtable` is intentionally disabled during normal builds but needs to run when pushing local changes back to Airtable.

**Example: Pushing rulebook changes back to Airtable:**
```bash
cd effortless-rulebook/push-to-airtable/
effortless build -id    # Runs rulebook-to-airtable (normally disabled)
```

## Installing Effortless Transpilers

Transpilers are installed using the `effortless` CLI with the `-install` flag. **CRITICAL: each tool MUST be installed from the directory where its output is expected.** The exact syntax is:

```bash
effortless -install <transpiler-name> -p param1=value1 -i input-file.txt -o output-file.json
```

The installed transpiler configuration is stored in `effortless.json` (or legacy `ssotme.json`) under `ProjectTranspilers`, recording:
- `RelativePath` — the folder the install was run from (relative to project root)
- `CommandLine` — the full command with all flags

### Standard Tool Installation Paths

Each tool MUST be installed from its designated directory:

```bash
# From /bootstrap/
effortless -install raw-text-to-rulebook -i requirements.txt -o bootstrap-rulebook.json

# From /effortless-rulebook/
effortless -install airtable-to-rulebook -o effortless-rulebook.json -account airtable

# From /effortless-rulebook/push-to-airtable/
# ** THIS TOOL MUST BE DISABLED — not run by default **
effortless -install rulebook-to-airtable -i ../effortless-rulebook.json -account airtable

# From /postgres/
effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json

# From /docs/
effortless -install rulebook-to-docs
```

**Critical:** The `rulebook-to-airtable` tool in `push-to-airtable/` must be disabled (`"IsDisabled": true`) so it is NOT run during a normal `effortless build`. It is only invoked explicitly with `effortless build -id` for reverse-sync (Path B).

Every airtable-facing tool MUST include `-account airtable` so the CLI sends the API key from `~/.ssotme/ssotme.key`.

## Pipeline Flow

```
Airtable Base (SSoT)
    |  airtable-to-rulebook
    v
effortless-rulebook.json (Intermediate Representation)
    |                    |                    |
    |  rulebook-to-      |  rulebook-to-      |  json-hbars-
    |  postgres          |  xlsx              |  transform
    v                    v                    v
postgres/            output.xlsx          README.SCHEMA.md
(00-05 SQL files)
    |  init-db
    v
Running PostgreSQL Database
```

## Multi-Substrate Architecture

The rulebook is **substrate-agnostic**. The same JSON generates equivalent implementations across:

| Substrate | Generated From | Role |
|-----------|---------------|------|
| **PostgreSQL** | `rulebook-to-postgres` | Primary reference (deterministic, full formula coverage) |
| **Python** | `inject-into-python.py` | Dataclasses + calc methods |
| **Go** | `inject-into-golang.py` | Structs + business logic |
| **Excel/XLSX** | `rulebook-to-xlsx` | Native spreadsheet formulas |
| **C# / .NET** | `odxml-to-csharp-pocos` | Entity Framework classes |
| **OWL/RDF** | `inject-into-owl.py` | Semantic web ontology |
| **YAML** | `inject-into-yaml.py` | LLM-friendly serialization |
| **UML** | `inject-into-uml.py` | PlantUML entity-relationship diagrams |

**Key principle:** No execution substrate defines truth; all substrates merely project and compute from the rulebook.

### Conformance Testing
- **Blank test**: Load data with calculated fields set to NULL
- **Execute**: Each substrate computes the calculated fields
- **Grade**: Compare output to answer-key. All deterministic substrates must match exactly.
