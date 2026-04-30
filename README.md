# Effortless Claude

A [Claude Code](https://claude.ai/claude-code) skill suite for working with **Effortless Rulebook (ERB)** projects — schema-first, Airtable-sourced, multi-substrate code generation.

## What This Does

Effortless Claude installs a set of modular skills into `~/.claude/skills/`. They auto-activate when Claude detects an ERB project (presence of `effortless.json` or an `effortless-rulebook/` directory) or when relevant phrases appear in conversation. Skills are progressive — Claude only loads what's needed for the task at hand.

The suite covers the full ERB lifecycle, not just code generation:

- **Bootstrap** new projects from raw requirements (the "Shadle steps")
- **Iterate** via the Leopold loop (CHANGE-RULE → REBUILD → CONSUME-VIEWS)
- **Generate** SQL, views, functions, and policies from the rulebook
- **Secure** apps with magic-link auth and Row-Level Security
- **Diagnose** schema and DAG issues

## What's an ERB Project?

An Effortless Rulebook project uses **Airtable as a single source of truth** for business schema and rules:

```
Airtable Base (humans + AI agents edit here)
    |
    | airtable-to-rulebook
    v
effortless-rulebook.json   (substrate-agnostic IR — the invariant)
    |          |          |          |
    v          v          v          v
PostgreSQL   Python      Go       Excel ...
(tables,     (classes,   (structs, (native
 functions,   calc        methods)  formulas)
 views,       methods)
 policies)
```

The rulebook JSON is the invariant. Generated code is disposable and regenerated from this single file. Schema changes go through Airtable.

### Key Files in an ERB Project

| File | Purpose |
|------|---------|
| `effortless.json` | Project config — base ID, transpiler pipeline |
| `effortless-rulebook/effortless-rulebook.json` | The rulebook — schema + data |
| `postgres/00-bootstrap.sql` | Database init (generated) |
| `postgres/01-drop-and-create-tables.sql` | Table DDL (generated) |
| `postgres/02-create-functions.sql` | `calc_*` / `get_*` functions (generated) |
| `postgres/03-create-views.sql` | `vw_*` views (generated — read from these, not tables) |
| `postgres/04-create-policies.sql` | RLS policies (generated) |
| `postgres/05-insert-data.sql` | Seed data (generated) |
| `postgres/*b-customize-*.sql` | User customizations (preserved across builds) |

## Skills

### Orchestration

| Skill | Purpose |
|-------|---------|
| `effortless-orchestrator` | Top-level orchestrator. Provides the mental model and routes to specialized skills. Auto-activates on `effortless.json` or `effortless-rulebook/`. |

### Project Lifecycle

| Skill | Purpose |
|-------|---------|
| `effortless-bootstrap` | The "Shadle steps" — turn raw requirements into a formal rulebook (vocabulary → glossary → narrative → mock data → schema → Airtable). |
| `effortless-leopold-loop` | The iterative ERB development cycle: CHANGE-RULE → REBUILD → CONSUME-VIEWS. Activates on "the loop", "do a turn", "rebuild the rulebook". |
| `effortless-setup-postgres` | First-step setup for any Postgres-targeted ERB project — installs the pipeline, pulls the rulebook, generates SQL, creates the database. |

### CLI

| Skill | Purpose |
|-------|---------|
| `effortless-install-cli` | Install or update the `effortless` CLI from source. Handles npm registration, prerequisites, and PATH. |
| `effortless-cli` | CLI command reference — login, install transpilers, set API keys, init projects, troubleshooting. |

### Schema & Conventions

| Skill | Purpose |
|-------|---------|
| `effortless-query` | Targeted, token-efficient queries against `effortless-rulebook.json` — list tables, extract schema, find FKs. |
| `effortless-schema` | Rulebook JSON structure reference — field types, datatypes, formula syntax, `_meta`. |
| `effortless-conventions` | Naming rules (PascalCase, the `Name` field as PK), DAG structure, no many-to-many, surrogate-key policy. |

### Workflow & Build

| Skill | Purpose |
|-------|---------|
| `effortless-workflow` | Change workflow — Path A (Airtable-first, preferred) vs Path B (rulebook-first reverse sync). Permission checkpoints. |
| `effortless-pipeline` | Build system reference — `effortless.json`, transpilers, `effortless build`, multi-substrate architecture. |

### Airtable Interaction

| Skill | Purpose |
|-------|---------|
| `effortless-airtable` | Airtable API for scalar field changes and CRUD. The default for most schema work. |
| `effortless-airtable-omni` | Escape hatch for what the API can't do — formula fields, lookups, rollups, new-table creation. Includes Playwright automation (`omni-send.mjs`). |

### Generated Code

| Skill | Purpose |
|-------|---------|
| `effortless-sql` | ERB SQL patterns — read from `vw_*` views, never edit `00`–`05` files, customize via `*b-customize-*.sql`. |

### Auth & Deployment

| Skill | Purpose |
|-------|---------|
| `effortless-bases` | The "create a base + magic-links tenant + RLS app in 5 minutes" flow against `bases.effortlessapi.com`. |
| `effortless-magic-links` | Add passwordless magic-link auth to **any** Postgres-backed app. Generalized beyond ERB. |

### Diagnostics

| Skill | Purpose |
|-------|---------|
| `effortless-diagnostics` | DAG validation, broken-FK checks, JOIN anti-pattern detection, legacy-code migration helpers. |

## Installation

### Option A: Ask Claude Code to install it

In any Claude Code session:

**macOS / Linux:**
```
Clone https://github.com/EffortlessAPI/effortless-claude and run install.sh
```

**Windows (Git Bash):**
```
Clone https://github.com/EffortlessAPI/effortless-claude and run install-windows.sh
```

### Option B: One-liner

**macOS / Linux:**
```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git /tmp/effortless-claude && bash /tmp/effortless-claude/install.sh && rm -rf /tmp/effortless-claude
```

**Windows (Git Bash):**
```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git /tmp/effortless-claude && bash /tmp/effortless-claude/install-windows.sh && rm -r /tmp/effortless-claude
```

### Option C: Clone and install

```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git
cd effortless-claude
bash install.sh              # macOS / Linux
bash install-windows.sh      # Windows (Git Bash)
```

### Installer flags

```
bash install.sh                # interactive — asks before overwriting
bash install.sh --yes          # non-interactive — overwrite without asking
bash install.sh --symlink      # symlink skills instead of copying (good for contributors)
bash install.sh --uninstall    # remove all installed effortless-* skills
bash install.sh --help         # show flags
```

## Updating

```bash
cd /path/to/effortless-claude
git pull
bash install.sh                # safe to re-run; prompts only on conflict
```

If you used `--symlink`, source updates are reflected automatically.

The installer cleans up deprecated skills listed in [`DEPRECATED_SKILLS.md`](DEPRECATED_SKILLS.md), prompting before removal.

## Verification

Start Claude Code in any ERB project directory (one containing `effortless.json` or `effortless-rulebook/`). Claude should:

1. Recognize it as an ERB project
2. Query `effortless-rulebook.json` before reading generated SQL
3. Read from `vw_*` views, not base tables, in app code
4. Refuse to edit generated SQL files (`00`–`05`); direct customizations to `*b-customize-*.sql`

Quick test: ask Claude *"What tables are in this rulebook?"* — it should parse the JSON directly rather than `cat`-ing SQL files.

## Project Structure

```
effortless-claude/
├── skills/
│   ├── effortless-orchestrator/        ← orchestrator (top-level)
│   ├── effortless-bootstrap/           ← Shadle steps (raw text → rulebook)
│   ├── effortless-leopold-loop/        ← the iteration cycle
│   ├── effortless-setup-postgres/      ← first-time Postgres setup
│   ├── effortless-install-cli/         ← install/update the CLI
│   ├── effortless-cli/                 ← CLI command reference
│   ├── effortless-query/               ← rulebook queries
│   ├── effortless-schema/              ← rulebook JSON structure
│   ├── effortless-conventions/         ← naming, DAG, PK rules
│   ├── effortless-workflow/            ← change workflow (Path A / B)
│   ├── effortless-pipeline/            ← build system
│   ├── effortless-airtable/            ← Airtable API (default)
│   ├── effortless-airtable-omni/       ← OMNI escape hatch (+ Playwright)
│   ├── effortless-sql/                 ← generated SQL patterns
│   ├── effortless-bases/               ← bases.effortlessapi.com flow
│   ├── effortless-magic-links/         ← portable magic-link auth (any Postgres app)
│   └── effortless-diagnostics/         ← DAG validation, migration helpers
├── CHANGELOG.md                        ← dated entries for repo-shape changes
├── DEPRECATED_SKILLS.md                ← deprecation registry (parsed by installer)
├── install.sh                          ← macOS / Linux installer
├── install-windows.sh                  ← Windows (Git Bash) installer
├── lint-skills.sh                      ← structural lint (frontmatter / naming / dep-registry)
├── LICENSE                             ← MIT
└── README.md
```

## Contributing

Each skill's `SKILL.md` is the source of truth for that skill's behavior. To suggest improvements:

1. Open an issue, or
2. Submit a PR editing the relevant `skills/effortless-*/SKILL.md`

For local development, install with `--symlink` so your edits to the source repo are reflected immediately:

```bash
bash install.sh --symlink
```

Before opening a PR, run the structural linter to catch frontmatter / naming / deprecation drift:

```bash
bash lint-skills.sh
```

It checks that every `SKILL.md` has YAML frontmatter, the `name:` field matches the directory name, an `audience:` is set (`customer` | `general`), deprecated skills carry `replaced_by:`, and that `DEPRECATED_SKILLS.md` is consistent with `skills/`.

For a chronological view of recent changes, see [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) — © EffortlessAPI