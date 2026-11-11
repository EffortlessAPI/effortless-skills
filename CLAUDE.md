# effortless-claude — Project CLAUDE.md

This project follows the **Effortless Rulebook (ERB) methodology**.
Marker pair (`effortless.json` + this file) tells Claude to load the project-only effortless-* skills.

## What this repo is

This is the **SSoT repo for the effortless skill suite itself** (GitHub `EffortlessAPI/effortless-skills`; older docs call it effortless-claude): one skill per folder under `skills/`. `bash lint-skills.sh` prints the current count; do not write the number down, it goes stale. It is packaged as a Claude Code **plugin** (`.claude-plugin/plugin.json`, plugin name `effortless`; `skills/` is auto-discovered) with its own marketplace (`.claude-plugin/marketplace.json` → `effortless@effortless-skills`). `install.sh` is the legacy path that copies `skills/*` into `~/.claude/skills/`.

**Skill descriptions share one character budget in every session's system prompt.** Keep each `description:` ≤ ~350 characters (triggers + one-phrase scope tag); the canonical load-gate policy lives in `effortless-orchestrator`, not in each description. When the budget overflows, Claude Code silently drops descriptions from the least-used skills and they stop triggering — that already happened once at ~30K total characters. It is also a (lightweight) ERB project that *describes itself* with its own methodology.

## What's special about this ERB project

- **A rulebook exists alongside the skills, describing them.** `effortless-rulebook/effortless-rulebook.json` mirrors the skill suite — tables `Skills`, `SkillCategories`, `ScopeGateTypes`, `Audiences`, plus `SkillBodies` (which stores each skill's `SKILL.md` text in `FullText`). There is no `airtable-to-rulebook` transpiler in the pipeline; the rulebook is hand-authored or edited through the **Rulebook Portal**.
- **A portal exists that CAN regenerate `SKILL.md` from the rulebook** (see below), and that direction — rulebook as the single source of truth, `SKILL.md` as a generated artifact — is the intended end state. **It is not the current state.** Treat it as a work in progress, not a completed cutover.

## SSoT discipline — `SKILL.md` files are still authoritative today

> **Reality check, current as of this file's last edit:** the most recent skill changes in this repo's git history are commits that touch `skills/*/SKILL.md` directly, with no corresponding edit to `effortless-rulebook.json` in the same commit. That means the rulebook can and does **lag behind** the skills. Don't trust a claim that the rulebook is current without checking `git log` on both paths first.

- **`skills/<name>/SKILL.md` is the actual source of truth.** Hand-editing it directly is the normal, correct way to change a skill today — not a shortcut that gets silently overwritten.
- **The rulebook-as-SSoT / portal-Commit-regenerates-everything model is the target design, not yet the practice.** The portal (see below) is real, working infrastructure and *can* perform that regeneration when run — but nothing in the current workflow forces every `SKILL.md` edit through it, and recent history shows edits routinely bypass it.
- **Derived/minimized artifacts** (any `.min.md`-style condensed file, `raw_skills.zip`, `install.sh`'s output) are downstream of `SKILL.md`, not the rulebook, whenever the rulebook is stale relative to the skills. If you need the authoritative text of a skill, read `skills/<name>/SKILL.md` — not the rulebook, not a minimized derivative.
- **Companion files** (every file under `skills/<name>/` other than `SKILL.md`: `REFERENCE.md`, `omni-send.mjs`, `effortless-rulebook-devops/reference/`, ...) are always hand-edited directly; the portal never regenerates them.

## The Rulebook Portal (an editing surface, not the enforced one)

`portal/` is a Vite + Node + docker-compose app for editing the rulebook and, when Committed, regenerating `SKILL.md` files from it. It is useful, working infrastructure for the eventual rulebook-first model — but do not assume it is where skill edits actually happen today.

- **Run it:** `cd portal && ./start.sh` → UI at http://localhost:5173, API at :5177, ephemeral Postgres at :55432.
- **Ephemeral by design:** on boot the portal seeds a **scratch Postgres** (tmpfs, in a Docker container) from the rulebook — which itself may already be stale relative to `skills/`. Edits live only in that scratch DB until Commit.
- **Commit, if run, is atomic-set regeneration:** DB → rewrite `effortless-rulebook.json` → regenerate **all** `SKILL.md` from `SkillBodies.FullText` → rebuild `raw_skills.zip` → run `minimize-rulebook` → run `lint-skills.sh`. This is real and it works — but it will **overwrite hand-edits to `SKILL.md`** with whatever is in the (possibly stale) rulebook. Do not run a portal Commit casually on a repo where `SKILL.md` files have been hand-edited more recently than the rulebook, without reconciling first.

## Workflow (current practice)

- **Modifying a skill (metadata or body) → edit `skills/<name>/SKILL.md` directly.** This is the actual, expected path. Optionally also update the corresponding `SkillBodies` row in the rulebook to keep it from drifting further — treat that as best-effort housekeeping, not a requirement for the skill edit to "count."
- Adding a new skill → add the `skills/<name>/SKILL.md` file (and its folder). Add matching `Skills`/`SkillBodies` rows to the rulebook if you're keeping it in sync; not required.
- Run `bash lint-skills.sh` before committing.
- Add a line to `CHANGELOG.md` under `[Unreleased]` (`Added` / `Changed` / `Fixed`) for every change a skill user would notice.
- Moving this repo toward the rulebook-first end state for real is a distinct, deliberate project (reconcile the rulebook against current `skills/`, then actually route edits through the portal going forward) — not something to assume has already happened.

## Ground rules for Claude in this repo

- **Work on `main`, commit and push when the change is done and lint passes** (owner, 2026-11-07: no side branches or worktrees; work left on a branch kept disappearing). Do not wait to be asked. One logical change per commit.
- **Other sessions share this checkout.** Stage only your own files and commit with explicit paths (`git commit -- <paths>`); a plain `git commit` takes whatever another session staged. When a file such as `CHANGELOG.md` also holds someone else's uncommitted lines, stage only your hunk and leave theirs in the working tree.
- **A push to `main` is a release.** Plugin users get it on their next update and the MCP server bakes it into its next image; write every skill as if it ships now.
- **Hand-editing `SKILL.md` files directly is correct and expected** — they are not silently regenerated out from under you in current practice. (This differs from the aspirational rulebook-first design described above; don't conflate the two.)
- **Don't edit the installed copies under `~/.claude/skills/effortless-*` directly** — they're downstream of `skills/`.
- **Keep skills concise** (~150 lines target). Skills are read by Claude, not human onboarders.
