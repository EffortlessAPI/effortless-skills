# effortless-claude — Project CLAUDE.md

This project follows the **Effortless Rulebook (ERB) methodology**.
Marker pair (`effortless.json` + this file) tells Claude to load the project-only effortless-* skills.

## What this repo is

This is the **SSoT repo for the effortless-claude skill suite itself** — the 31 skills under `skills/` that get installed to `~/.claude/skills/` via `install.sh`. It is also a (lightweight) ERB project that *describes itself* with its own methodology.

## What's special about this ERB project

- **A rulebook exists alongside the skills, describing them.** `effortless-rulebook/effortless-rulebook.json` mirrors the skill suite — tables `Skills`, `SkillCategories`, `ScopeGateTypes`, `Audiences`, plus `SkillBodies` (which stores each skill's `SKILL.md` text in `FullText`). There is no `airtable-to-rulebook` transpiler in the pipeline; the rulebook is hand-authored or edited through the **Rulebook Portal**.
- **A portal exists that CAN regenerate `SKILL.md` from the rulebook** (see below), and that direction — rulebook as the single source of truth, `SKILL.md` as a generated artifact — is the intended end state. **It is not the current state.** Treat it as a work in progress, not a completed cutover.

## SSoT discipline — `SKILL.md` files are still authoritative today

> **Reality check, current as of this file's last edit:** the most recent skill changes in this repo's git history are commits that touch `skills/*/SKILL.md` directly, with no corresponding edit to `effortless-rulebook.json` in the same commit. That means the rulebook can and does **lag behind** the skills. Don't trust a claim that the rulebook is current without checking `git log` on both paths first.

- **`skills/<name>/SKILL.md` is the actual source of truth.** Hand-editing it directly is the normal, correct way to change a skill today — not a shortcut that gets silently overwritten.
- **The rulebook-as-SSoT / portal-Commit-regenerates-everything model is the target design, not yet the practice.** The portal (see below) is real, working infrastructure and *can* perform that regeneration when run — but nothing in the current workflow forces every `SKILL.md` edit through it, and recent history shows edits routinely bypass it. Don't assume "the rulebook must reflect this because a Commit ran" — verify.
- **Derived/minimized artifacts** (any `.min.md`-style condensed file, `raw_skills.zip`, `install.sh`'s output) are downstream of `SKILL.md`, not the rulebook, whenever the rulebook is stale relative to the skills. If you need the authoritative text of a skill, read `skills/<name>/SKILL.md` — not the rulebook, not a minimized derivative.
- **Companion files** — `skills/effortless-airtable-omni/omni-send.mjs`, `skills/*/REFERENCE.md`, `skills/effortless-rulebook-devops/reference/` — are always hand-edited directly regardless of any of the above.

## The Rulebook Portal (an editing surface, not the enforced one)

`portal/` is a Vite + Node + docker-compose app for editing the rulebook and, when Committed, regenerating `SKILL.md` files from it. It is useful, working infrastructure for the eventual rulebook-first model — but do not assume it is where skill edits actually happen today, and do not assume the rulebook it edits is currently in sync with `skills/`.

- **Run it:** `cd portal && ./start.sh` → UI at http://localhost:5173, API at :5177, ephemeral Postgres at :55432.
- **Ephemeral by design:** on boot the portal seeds a **scratch Postgres** (tmpfs, in a Docker container) from the rulebook — which itself may already be stale relative to `skills/`. Edits live only in that scratch DB until Commit.
- **Commit, if run, is atomic-set regeneration:** DB → rewrite `effortless-rulebook.json` → regenerate **all** `SKILL.md` from `SkillBodies.FullText` → rebuild `raw_skills.zip` → run `minimize-rulebook` → run `lint-skills.sh`. This is real and it works — but it will **overwrite hand-edits to `SKILL.md`** with whatever is in the (possibly stale) rulebook. Do not run a portal Commit casually on a repo where `SKILL.md` files have been hand-edited more recently than the rulebook, without reconciling first.

## Workflow (current practice)

- **Modifying a skill (metadata or body) → edit `skills/<name>/SKILL.md` directly.** This is the actual, expected path. Optionally also update the corresponding `SkillBodies` row in the rulebook to keep it from drifting further — treat that as best-effort housekeeping, not a requirement for the skill edit to "count."
- Adding a new skill → add the `skills/<name>/SKILL.md` file (and its folder). Add matching `Skills`/`SkillBodies` rows to the rulebook if you're keeping it in sync; not required.
- Run `bash lint-skills.sh` before opening a PR.
- If someone wants to move this repo toward the rulebook-first end state for real, that's a distinct, deliberate project (reconcile the rulebook against current `skills/`, then actually route edits through the portal going forward) — don't assume it's already been done because this file once said so.

## Ground rules for Claude in this repo

- **Don't auto-commit.** The user reviews and commits manually. Setup/install/portal steps don't bypass this.
- **Hand-editing `SKILL.md` files directly is correct and expected** — they are not silently regenerated out from under you in current practice. (This differs from the aspirational rulebook-first design described above; don't conflate the two.)
- **Don't edit the installed copies under `~/.claude/skills/effortless-*` directly** — they're downstream of `skills/`.
- **Keep skills concise** (~150 lines target). Skills are read by Claude, not human onboarders.
