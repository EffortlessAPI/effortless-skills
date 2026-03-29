# Effortless Claude

A [Claude Code](https://claude.ai/claude-code) skill suite for working with **Effortless Rulebook (ERB)** projects — schema-first, Airtable-sourced, multi-substrate code generation.

## What This Does

Effortless Claude installs a set of modular skills into `~/.claude/skills/`. These skills are **scope-gated** — they don't activate willy-nilly across every Claude session. They load when:

- You're in a project that has been **explicitly marked as Effortless** (the project root contains both `effortless.json` and a `CLAUDE.md` that identifies the project as following ERB methodology), **or**
- You **explicitly invoke** them by phrase — e.g. "make this an effortless project", "install the effortless CLI", "explain CMCC", "set up magic links on this app".

This means you can install the suite globally without it crashing the party in your unrelated Postgres/Python/whatever project. The skills stay quiet until you're actually working on an Effortless project (or you ask for one).

The suite covers the full ERB lifecycle:

- **Bootstrap** new projects from raw requirements (the "Shadle steps")
- **Initialize** the project structure, CLAUDE.md marker, and Airtable connection
- **Iterate** via the Leopold loop (CHANGE-RULE → REBUILD → CONSUME-VIEWS)
- **Generate** SQL, views, functions, and policies from the rulebook
- **Secure** apps with magic-link auth and Row-Level Security
- **Diagnose** schema and DAG issues
- **Defend** the methodology with receipts (CMCC, conformance suite, repo catalog)

## What's an ERB Project?

An Effortless Rulebook project uses **Airtable as the single source of truth** for business schema and rules:

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

The rulebook JSON is the invariant. Generated code is disposable and regenerated from this single file. Schema changes go through Airtable, not through hand-edited generated artifacts.

### The Effortless project marker

A project is "Effortless" if and only if **both** are true:

1. `effortless.json` (or legacy `ssotme.json`) exists at the project root.
2. A `CLAUDE.md` at the project root explicitly identifies the project as following the Effortless Rulebook (ERB) methodology.

This dual marker is what tells Claude to load the project-only skills (the ones that read your rulebook, write to your Airtable, regenerate your SQL). Entry-point skills like `effortless-init` and `effortless-cli` can also load on explicit user request, since their job is to *create* the marker or manage tooling.

### Key files in an ERB project

| File | Purpose |
|---|---|
| `effortless.json` | Project config — base ID, transpiler pipeline |
| `CLAUDE.md` | Project-level marker + per-project rules for Claude |
| `effortless-rulebook/effortless-rulebook.json` | The rulebook — schema + data |
| `postgres/00-bootstrap.sql` | Database init (generated) |
| `postgres/01-drop-and-create-tables.sql` | Table DDL (generated) |
| `postgres/02-create-functions.sql` | `calc_*` / `get_*` functions (generated) |
| `postgres/03-create-views.sql` | `vw_*` views (generated — read from these, not tables) |
| `postgres/04-create-policies.sql` | RLS policies (generated) |
| `postgres/05-insert-data.sql` | Seed data (generated) |
| `postgres/*b-customize-*.sql` | User customizations (preserved across builds) |

## Skills

23 skills, grouped by purpose. Each one explains *why you'd want it* — what problem it actually solves for you when you reach for it.

### Orchestration

**`effortless-orchestrator`** — Top-level mental model and router. Defines what an Effortless project is, the load-bearing axioms (rulebook-as-invariant, generated-code-as-disposable), the schema-change decision tree, the canonical Token Discipline rule, and the routing table to every other skill. **Why?** Because without a top-level frame, Claude will improvise — and improvisation in ERB means editing generated SQL and reimplementing business logic in app code. The orchestrator keeps the model coherent across whatever sub-skill is loaded next.

### Project Lifecycle

**`effortless-init`** — Turns any folder into an Effortless project: runs `effortless -init`, creates the standard directory layout (`effortless-rulebook/`, `postgres/`, etc.), writes the project-level CLAUDE.md, and generates a `start.sh`. **Why?** Without the CLAUDE.md marker, future Claude sessions can't recognize the project as Effortless and the rest of the suite won't load. This skill installs the gate that opens everything else.

**`effortless-bootstrap`** — The "Shadle steps": raw text → vocabulary → glossary → narrative → mock data → schema → Airtable. **Why?** Going from "here's what we want to build" to "we have a formal rulebook" is the fuzziest part of ERB. This skill is the structured pipeline for that translation, so you don't end up with a half-formal mess that can't be projected to a substrate.

**`effortless-setup-postgres`** — First-run setup for Postgres-targeted projects: preflight tool checks, install the airtable-to-rulebook + rulebook-to-postgres transpilers, pull the rulebook, generate SQL, init the local DB. **Why?** This is the only step where commits are appropriate without asking (it's a known-good bootstrap sequence), and it gets you from "I have an Airtable base" to "I have a working local DB + generated views" without you having to remember the per-step `cd` discipline that makes the build work.

**`effortless-setup-sql-server`** — First-run setup for SQL Server–targeted projects: install `rulebook-to-sql-server` into `sql-server/`, patch `init-db.sh` defaults, register the `-exec ./init-db.sh` build step, preflight `sqlcmd` + Docker MSSQL, and wire the Express app to `mssql`. **Why?** The SQL Server transpiler mirrors the Postgres pipeline (same `00`–`05` + `vw_*` pattern) but uses T-SQL, security policies instead of Postgres RLS, and `sqlcmd` instead of `psql` — this skill encodes those differences so agents don't improvise.

**`effortless-leopold-loop`** — The iterative ERB development cycle: CHANGE-RULE (in Airtable) → `effortless build` → CONSUME generated views in app code → repeat. **Why?** Without it you'll regress to "naked Claude" — hand-maintaining schema in three places (DB migration, ORM model, API serializer) and breaking sync every time something changes. The loop is the thing that makes ERB feel effortless instead of redundant.

**`effortless-claude-updates`** — Everything about the **skill set itself**: check whether your local clone is behind upstream, apply updates (`git pull` + `install.sh`), add/edit/deprecate skills. **Why?** The skill set is its own moving target — new skills get added, old ones get merged, conventions drift. This skill is the maintenance interface for the suite (separate from the CLI binary, which is `effortless-cli`).

### CLI

**`effortless-cli`** — Both **installing/updating the `effortless` binary** and **using it**. Covers prerequisites (.NET 8, Node 18+), the npm-package install (clones `effortlessapi/cli`, registers `effortless` / `ssotme` / `aicapture` / `aic` shims), nvm coexistence pitfalls, login flow, `-init`, `-setAccountAPIKey`, transpiler installation paths, build flags, project file structure. **Why?** Because nothing in the rest of the suite works without the CLI being on `PATH` and pointing at the right Node version. This skill is also where the `effortless: command not found` recovery flow lives.

**`effortless-mcp`** — Install and use the always-on **Effortless MCP server** — the streamable-HTTP endpoint that exposes ~54 transpiler tools (auto-generated from the Airtable catalog) plus the effortless-claude skill set as MCP **Resources** to any MCP-compatible agent (Claude Code, Cursor, Windsurf, ChatGPT, etc.). Covers the deployed cpln URL, per-client wiring snippets, smoke tests, local dev (`./start.sh`, stdio mode), and the bake/publish flow for new versions. **Why?** The CLI binary is not the only way to drive the catalog — MCP is the protocol-level surface that lets non-Claude agents (and Claude in non-CLI contexts) call transpilers, run builds, query rulebooks, and read skills without anything installed locally.

**`effortless-publish-tool`** — **Publish / push / deploy / release a new version of a transpiler tool** in `Versioned-Stable-SSoTme-Tools`. The one supported scripted path is `scripts/publish-tool.sh <transpilerId> <category>/<tool-name>` (the same sequence as the green 🚀 Deploy button: Airtable version → build+push cpln image → wait online → flip `[latest]` live). **Why?** "Push the tool online" reads as trivial but has a precise contract, and the two most common stumbles are (1) concluding the transpiler-server is "down" when it's just on a non-3000 `PORT` (find it; pass `API_BASE`), and (2) confusing the real publish with `build-and-push-cpln-workload.sh` (build only) or `effortless build` (consume). This skill encodes that contract so push/publish/deploy requests don't get re-derived from scratch.

### Schema & Conventions

**`effortless-conventions`** — Naming rules (`Name` is always the first field and the logical PK; PascalCase plural table names; singular FKs with no `Id` suffix; plural reverse FKs); DAG structure (1-to-many only, no cycles, no many-to-many); surrogate-key policy (substrate's problem, never in the rulebook). **Why?** These rules look arbitrary until you realize they're what makes the substrate-equivalence guarantee hold. Read this before "fixing" something the linter complains about, because the linter is usually right.

**`effortless-schema`** — Reference for the **structure** of `effortless-rulebook.json`: top-level keys, table objects, the field schema, the five field types (raw / calculated / lookup / relationship / aggregation), datatypes, formula syntax (Excel dialect), the `_meta` section. **Why?** When you need to know "what does a calculated field look like in JSON" or "how is a relationship encoded", you want a 1-screen reference, not to grep through example rulebooks.

**`effortless-query`** — Targeted, token-efficient one-liners against `effortless-rulebook.json`: list tables, extract schema for one table, find FK relationships, inspect calculated fields and formulas. **Why?** The rulebook can be megabytes once it has data. Reading it whole burns your context window for nothing — you only ever needed the schema fragment for one table. This skill keeps you in the lightweight-query habit.

### Workflow & Build

**`effortless-workflow`** — The two valid paths for making changes: **Path A** (Airtable-first, preferred) and **Path B** (rulebook-first reverse sync via `build -id`). Permission checkpoints — when to ask before modifying the rulebook, Airtable, or running a build. **Why?** Most "this didn't work" stories in ERB are someone editing the rulebook JSON directly when Path A would have been right, then `effortless build` overwriting their edits. This skill is the discipline that prevents that.

**`effortless-pipeline`** — How `effortless.json`, `ProjectTranspilers`, and `effortless build` actually work: the catalog of transpilers, the `-id` flag, the multi-substrate architecture (Postgres, Python, Go, Excel, OWL, YAML, UML, …), and the standard install paths for each tool. **Why?** When the build does something surprising — a transpiler doesn't run, a generated file lands in the wrong directory, `-id` does something different than `build` — this skill is the "how does the pipeline actually work" reference.

### Airtable Interaction

**`effortless-airtable`** — The **default** for Airtable changes: scalar field add/modify/rename, table creation (without formulas), and all CRUD operations via the REST API. Includes the `-account airtable` flag pattern and the `~/.ssotme/ssotme.key` resolution order. **Why?** ~80% of Airtable changes are scalar fields or CRUD — the API handles them in a few seconds. Falling back to OMNI (Playwright) for these is wasteful.

**`effortless-airtable-omni`** — The **escape hatch** for what the API can't do: formula fields, lookup fields, rollup fields, and new-table creation (which requires the `Name` formula). Includes the bundled Playwright script (`omni-send.mjs`) that drives a headed Chrome to OMNI directly — Claude doesn't generate prompts for you to paste, it sends them. **Why?** Without this skill Claude either can't add a formula field at all, or wastes everyone's time generating OMNI prompts for you to copy-paste manually. With it, formula/lookup/rollup work happens automatically.

### Generated Code

**`effortless-sql`** — Patterns for the generated SQL: read from `vw_*` views (never base tables), never edit `00`–`05` files (regenerated every build), customize via `*b-customize-*.sql` and the `ERBCustomizations` table only when the rulebook genuinely can't express the rule. **Why?** This is where most "fixes" go wrong: someone edits `02-create-functions.sql` to "patch" a behavior, the next build erases it, the bug comes back, and now there's a phantom commit history with no surviving code. This skill is the rule that prevents that whole class of incident.

### Auth & Deployment

**`effortless-bases`** — End-to-end "create a base + magic-links tenant + RLS-secured app in 5 minutes" flow on `bases.effortlessapi.com`. Covers tenant creation, registering trusted tenants on the base, applying the two-role privilege template, and writing email-DAG RLS policies. **Why?** When you want a hosted Postgres + auth without setting up a backend, this is the shortest path from zero to "users can log in and only see their own data". The skill encodes the gotchas that aren't in the docs.

**`effortless-magic-links`** — Add passwordless email-code (magic-link) auth to **any** Postgres-backed app, not just `bases.effortlessapi.com`. Mints a tenant on `magiclink.effortlessapi.com`, stores the public key, wires `Authorization: Bearer` middleware, and (optionally) installs `app.jwt_*()` SQL helpers so RLS can filter by verified email. **Why?** Magic-links is a notary, not a referee — it just verifies "we sent code C to email E, the holder returned it." That clean separation means you can layer it onto any existing app without rewriting your user model. This skill encodes the wiring.

### Diagnostics

**`effortless-diagnostics`** — DAG validation (find missing FK targets), broken-FK checks, JOIN anti-pattern detection in app code, legacy-code migration helpers (rewrite base-table reads to view reads). **Why?** ERB projects accumulate two kinds of debt: rulebook entries with broken references (deleted tables, renamed FKs), and app code that reads from base tables instead of views. Both compound silently. This skill surfaces them.

### Theory & Receipts

**`effortless-cmcc`** — The conceptual floor: SDLAF, the bitemporal ACID DAG, the 5 primitives, what the Conceptual Model Completeness Conjecture predicts and forbids. **Why?** When someone (you, a teammate, a skeptic) asks "WHY is ERB structured this way? Isn't this overkill?" — improvising the answer makes it sound arbitrary. This skill grounds the answer in the conjecture, so the response is consistent across sessions.

**`effortless-rulebooks`** — The empirical demonstration: 11+ substrates (including ARM64, COBOL, OWL/SHACL, English), the conformance suite, ExplainDAG, `answer-key.json`. Pointer into [github.com/effortlessapi/effortless-rulebooks](https://github.com/effortlessapi/effortless-rulebooks). **Why?** When the response to a "does this actually work?" question needs to be "yes, here's the runnable proof" — this skill is the catalog of runnable proofs.

**`effortless-rationale`** — Skeptic-facing answers, strictly grounded in receipts (papers, repos, runnable demos). Common objections — "isn't this just MDE", "isn't this just low-code", "why Airtable", "isn't this overkill" — paired with cited responses. **Why?** When the methodology needs to be defended (to a skeptical reviewer, an architecture committee, a Hacker News thread), the responses should cite, not enthuse. This skill enforces that.

**`effortless-ecosystem`** — The OSS catalog: every public repo in the [SSoTme](https://github.com/SSoTme) and [effortlessapi](https://github.com/effortlessapi) GitHub orgs, with one-liner descriptions and install snippets. **Why?** "Where is the source for X?" / "Is there a transpiler for Y?" come up constantly. Without this skill, Claude guesses; with it, the answer is cited.

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

You can ask Claude — `effortless-claude-updates` is the skill that drives this:

```
"Are my effortless skills up to date?"
"Update effortless skills."
```

Or do it yourself:

```bash
cd /path/to/effortless-claude
git pull
bash install.sh                # safe to re-run; prompts only on conflict
```

If you used `--symlink`, source updates are reflected automatically — no reinstall needed.

The installer cleans up deprecated skills listed in [`DEPRECATED_SKILLS.md`](DEPRECATED_SKILLS.md), prompting before removal.

## Verification

Start Claude Code in any **marked Effortless project** (one containing both `effortless.json` and a CLAUDE.md identifying the project as ERB). Claude should:

1. Recognize it as an ERB project and load the orchestrator
2. Query `effortless-rulebook.json` before reading generated SQL
3. Read from `vw_*` views, not base tables, in app code
4. Refuse to edit generated SQL files (`00`–`05`); direct customizations to `*b-customize-*.sql`
5. Ask permission before running `effortless build` or modifying the rulebook

Quick test: ask Claude *"What tables are in this rulebook?"* — it should run a targeted JSON query rather than `cat`-ing SQL files.

In a project that **isn't** marked Effortless, the project-only skills should stay quiet. You can still invoke entry points by phrase — "make this an effortless project", "install the effortless cli", "explain CMCC".

## Project Structure

```
effortless-claude/
├── skills/
│   ├── effortless-orchestrator/        ← top-level mental model + routing
│   ├── effortless-init/                ← initialize a project as Effortless
│   ├── effortless-bootstrap/           ← Shadle steps (raw text → rulebook)
│   ├── effortless-setup-postgres/      ← first-run Postgres setup
│   ├── effortless-setup-sql-server/    ← first-run SQL Server setup
│   ├── effortless-leopold-loop/        ← the iteration cycle
│   ├── effortless-claude-updates/      ← skill-set maintenance
│   ├── effortless-cli/                 ← CLI binary install + command reference
│   ├── effortless-mcp/                 ← MCP server install + per-client wiring
│   ├── effortless-publish-tool/        ← publish/deploy a new transpiler-tool version
│   ├── effortless-conventions/         ← naming, DAG, PK/FK rules
│   ├── effortless-schema/              ← rulebook JSON structure
│   ├── effortless-query/               ← token-efficient rulebook queries
│   ├── effortless-workflow/            ← Path A / B change workflow
│   ├── effortless-pipeline/            ← build system internals
│   ├── effortless-airtable/            ← Airtable API (default for scalar/CRUD)
│   ├── effortless-airtable-omni/       ← OMNI escape hatch (+ Playwright)
│   ├── effortless-sql/                 ← generated SQL patterns
│   ├── effortless-bases/               ← bases.effortlessapi.com flow
│   ├── effortless-magic-links/         ← portable magic-link auth (any Postgres app)
│   ├── effortless-diagnostics/         ← DAG validation, migration helpers
│   ├── effortless-cmcc/                ← theory: the conjecture
│   ├── effortless-rulebooks/           ← receipts: runnable substrates
│   ├── effortless-rationale/           ← skeptic-facing defense (receipts only)
│   └── effortless-ecosystem/           ← repo catalog (SSoTme + effortlessapi orgs)
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

### Skill-writing conventions

- **Concise.** Skills are read by Claude, not by humans onboarding. Target ~150 lines per `SKILL.md`. Lead with rules and axioms; skip tutorial framing.
- **Scope gate.** Every skill's `description` includes a `**Scope (load gate):**` clause that tells Claude when *not* to load the skill. See existing skills for the four patterns (project-only / entry-point / tooling / theory).
- **Link, don't repeat.** If another skill covers the same content, link to it rather than restating.
- **Axiom on top.** Every non-trivial skill opens with a 1–2 line load-bearing axiom that captures the model.

For a chronological view of recent changes, see [CHANGELOG.md](CHANGELOG.md).

## License

[MIT + Commons Clause](LICENSE) — © EffortlessAPI

This project is free for personal, educational, and non-profit use. **Commercial use requires a license.** If you're using these skills to generate revenue or commercial benefit, please contact EffortlessAPI for licensing terms. See the [LICENSE](LICENSE) file for full details.
