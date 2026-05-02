# effortless-claude — Project CLAUDE.md

This project follows the **Effortless Rulebook (ERB) methodology**.
Marker pair (`effortless.json` + this file) tells Claude to load the project-only effortless-* skills.

## What this repo is

This is the **SSoT repo for the effortless-claude skill suite itself** — the 23 skills under `skills/` that get installed to `~/.claude/skills/` via `install.sh`. It is also a (lightweight) ERB project that *describes itself* with its own methodology.

## What's special about this ERB project

- **Hand-authored rulebook.** `effortless-rulebook/effortless-rulebook.json` is written by hand, not generated from Airtable. There is no `airtable-to-rulebook` transpiler in the pipeline.
- **No code-generation substrate.** No Postgres, no Python, no Go output. The skills are the artifact. `ProjectTranspilers` is empty.
- **The rulebook describes the skill suite.** Tables: `Skills`, `SkillCategories`, `ScopeGateTypes`, `Audiences`. Each skill folder under `skills/` corresponds to one row in `Skills`.

## SSoT discipline

`skills/` in this repo is the source of truth for the installed copies under `~/.claude/skills/`. Always edit here first, then re-run `install.sh` (or use `--symlink` for live editing). Never edit the installed copy directly.

## Workflow

- Adding/modifying a skill → edit `skills/<name>/SKILL.md`, then add a corresponding row to the `Skills` table in the rulebook.
- Adding a new category or scope-gate pattern → add a row to `SkillCategories` or `ScopeGateTypes` first, then reference it from the relevant `Skills` row.
- Run `bash lint-skills.sh` before opening a PR.

## Ground rules for Claude in this repo

- **Don't auto-commit.** The user reviews and commits manually. Setup/install steps don't bypass this.
- **Don't edit the installed copies under `~/.claude/skills/effortless-*` directly** — they're downstream of `skills/` here.
- **Keep skills concise** (~150 lines target). Skills are read by Claude, not human onboarders.
