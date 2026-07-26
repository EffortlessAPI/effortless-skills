# effortless-claude — Project CLAUDE.md

This project follows the **Effortless Rulebook (ERB) methodology**.
Marker pair (`effortless.json` + this file) tells Claude to load the project-only effortless-* skills.

## What this repo is

This is the **SSoT repo for the effortless-claude skill suite itself** — the 31 skills under `skills/` that get installed to `~/.claude/skills/` via `install.sh`. It is also a (lightweight) ERB project that *describes itself* with its own methodology.

## What's special about this ERB project

- **Hand-authored rulebook, now the authoritative hub.** `effortless-rulebook/effortless-rulebook.json` is written/edited by hand or through the **Rulebook Portal** (see below), not generated from Airtable. There is no `airtable-to-rulebook` transpiler in the pipeline.
- **The rulebook is internally complete.** The `SkillBodies` section stores the **full text of every skill's `SKILL.md` verbatim** (byte-for-byte, in `FullText`). *If you have the rulebook, you have the skills.* Skills-table rows stay thin (Description, Category, ScopeGate, Audience); the body text lives in the parallel `SkillBodies` section.
- **The rulebook describes AND contains the skill suite.** Tables: `Skills`, `SkillCategories`, `ScopeGateTypes`, `Audiences`, plus `SkillBodies`. Each skill folder under `skills/` corresponds to one row in `Skills` and one row in `SkillBodies`.

## SSoT discipline — the rulebook is authoritative; SKILL.md files are GENERATED

> **This inverted on 2026-07-26.** Before that, `skills/*/SKILL.md` was the source of truth and the rulebook merely described the suite. **That is no longer true.**

- **`effortless-rulebook/effortless-rulebook.json` is the single source of truth** for both skill *metadata* (Skills/Categories/ScopeGates/Audiences) and skill *body text* (`SkillBodies.FullText`).
- **`skills/<name>/SKILL.md` files are GENERATED artifacts** — regenerated from `SkillBodies.FullText` on every portal Commit. **Do not hand-edit a `SKILL.md` expecting it to persist** — the next Commit overwrites it from the rulebook. Edit the rulebook (via the portal, or the `SkillBodies` row directly with permission) instead.
- Downstream of the rulebook, in order: `skills/*/SKILL.md` → `install.sh` → `~/.claude/skills/`, and `raw_skills.zip`. Never edit an installed copy directly; never edit a generated `SKILL.md` directly.
- **Companion files are NOT generated** and are safe to edit directly: `skills/effortless-airtable-omni/omni-send.mjs`, `skills/*/REFERENCE.md`, `skills/effortless-rulebook-devops/reference/`. Only `SKILL.md` is rulebook-owned.

## The Rulebook Portal (the editing surface)

`portal/` is a Vite + Node + docker-compose app for editing the rulebook. It is the intended editing surface for the skills.

- **Run it:** `cd portal && ./start.sh` → UI at http://localhost:5173, API at :5177, ephemeral Postgres at :55432.
- **Ephemeral by design:** on boot the portal seeds a **scratch Postgres** (tmpfs, in a Docker container) from the rulebook. Edits live only in that scratch DB — *an edit is only as stable as it is until you Commit.* Losing the container loses only uncommitted edits.
- **Commit is atomic-set regeneration:** DB → rewrite `effortless-rulebook.json` (style-preserving, so diffs stay minimal) → regenerate **all** `SKILL.md` from `SkillBodies.FullText` → rebuild `raw_skills.zip` → run `minimize-rulebook` (`effortless build`) → run `lint-skills.sh`. Everything updates together as one set.
- **Lossless guarantee:** a no-op Commit is a zero-diff and every `SKILL.md` regenerates byte-identically to `SkillBodies.FullText`. This is the invariant that makes the rulebook safe to treat as authoritative.

## Workflow

- Modifying a skill (metadata or body) → edit in the **portal**, then **Commit** (regenerates the whole set). Or edit the rulebook's `Skills`/`SkillBodies` row directly with permission, then run the same regenerate/build steps.
- Adding a new skill → add a `Skills` row AND a `SkillBodies` row (with the full `SKILL.md` text in `FullText`), then Commit.
- Adding a new category or scope-gate pattern → add a row to `SkillCategories` or `ScopeGateTypes` first, then reference it from the relevant `Skills` row.
- Run `bash lint-skills.sh` before opening a PR (the portal Commit already runs it).

## Ground rules for Claude in this repo

- **Don't auto-commit.** The user reviews and commits manually. Setup/install/portal steps don't bypass this.
- **Don't hand-edit generated `SKILL.md` files** — they're regenerated from the rulebook. Edit the rulebook.
- **Don't edit the installed copies under `~/.claude/skills/effortless-*` directly** — they're downstream of `skills/`, which is itself downstream of the rulebook.
- **Keep skills concise** (~150 lines target). Skills are read by Claude, not human onboarders.
