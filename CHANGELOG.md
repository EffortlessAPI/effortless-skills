# Changelog

All notable changes to the Effortless Claude skill suite are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses date-based versioning rather than semver — each
release section is an ISO date.

## [Unreleased]

### Added
- **`effortless-rulespeak`** — install `rulebook-to-rulespeak`, emit
  `rulespeak/rulespeak.md` (plain-English declarative business rules).

### Changed
- **`start.sh` contract** (`effortless-init`, `effortless-setup-postgres`,
  `effortless-demo-app`) — per project: hard-code a random **odd** `API_PORT`
  and **even** `UI_PORT = API_PORT + 1`. `./start.sh` (no args) always kills
  both ports and restarts API + SPA, printing `http://localhost:` links for
  both. Optional subcommands: `build`, `db` only — no `all`/`server`/`web`.
- **`effortless-demo-app`** — POC bootstrap step F now installs RuleSpeak
  instead of the Explainer DAG; no `data-er-dag` wiring in default demos.
- **`effortless-explainer-dag`** — explicitly on-demand only; not part of
  standard POC path.
- **`effortless-orchestrator`** / **`effortless-pipeline`** — document
  RuleSpeak as default doc output; Explainer DAG as optional add-on.

### Added
- **Load-bearing axioms.** Every non-trivial skill now opens with a 1–2
  line axiom that captures the model:
  - `effortless-orchestrator`: "The rulebook is the invariant; generated code is disposable."
  - `effortless-sql`: "Generated SQL is a projection, not a source."
  - `effortless-conventions`: "Name is the primary key. Surrogates are the substrate's problem."
  - `effortless-airtable-omni`: "OMNI is an escape hatch, not the default."
  - `effortless-magic-links` and `effortless-bases` already carried
    "Magic-links is a notary, not a referee."
- **Canonical Token Discipline section** in `effortless-orchestrator`.
  Leaf skills (`effortless-query`, `effortless-sql`, `effortless-pipeline`,
  `effortless-setup-postgres`) now point at it instead of restating their
  own variant.
- **`## See also` footer** on every SKILL.md, listing related skills with
  a one-line "when to use that one instead" hook.
- **`audience:` frontmatter key** on every skill — `customer` for
  EffortlessAPI-customer-specific flows, `general` for skills that work
  for any project (currently just `effortless-magic-links`).
- **`CHANGELOG.md`** (this file) — dated entries for all repo-shape changes.
- **`lint-skills.sh`** structural linter — every `SKILL.md` must have YAML
  frontmatter with `name:` matching its directory; deprecated skills must
  carry `replaced_by:`. Run it from the repo root before opening a PR.
- **REFERENCE.md split** for the two longest skills:
  - `effortless-magic-links/REFERENCE.md` — Pattern B (in-DB JWT verify),
    role-resolver recursion gotcha, refresh flow, multi-DB tenant sharing,
    full cheat sheet.
  - `effortless-setup-postgres/REFERENCE.md` — per-OS preflight install
    options, Step 7 prototype-app + `start.sh` skeleton, Common Issues
    troubleshooting table.
- **`omni-send.mjs` prerequisites section** in `effortless-airtable-omni`
  — Node 18+, Playwright + Chromium, headed display, persistent profile,
  network access, valid base id. Stop and tell the user if any are missing.
- **"Naked Claude" defined on first use** in `effortless-leopold-loop`
  (coding without the rulebook — every layer hand-maintained).

### Changed
- **Renamed `magic-links` → `effortless-magic-links`** to align with the
  `effortless-` prefix convention. The old skill is registered in
  `DEPRECATED_SKILLS.md`; the installer offers to clean up the old
  `~/.claude/skills/magic-links` directory on next run.
- **Renamed orchestrator skill `effortless-claude` → `effortless-orchestrator`**
  to remove the name collision with the parent repo (still
  `effortless-claude`). Same triggers; same content; clearer routing.
- **All `ssotme.json` references replaced with `effortless.json`** across
  skills, README, and the bundled `omni-send.mjs`. The CLI still accepts
  the legacy filename, but the docs no longer mention it. The
  `~/.ssotme/ssotme.key` API-key store and the `ssotme` / `aicapture` CLI
  bin aliases keep their names — those are separate from the project file.
- **License changed from "Proprietary, all rights reserved" to MIT.**
  See [LICENSE](LICENSE).
- **Trigger-phrase boundary tightened** between `effortless-orchestrator`
  (skill set updates) and `effortless-install-cli` (CLI binary). The two
  used to overlap on phrases like "reinstall effortless"; now the
  orchestrator only matches "update/reinstall effortless **skills**" and
  install-cli only matches "install/update effortless **CLI**" or
  `effortless: command not found`.
- **`DEPRECATED_SKILLS.md` schema** gained `Deprecated On` and
  `Target Removal` columns. The installer still parses by column 2 only,
  so the existing deprecation cleanup keeps working.
- **`effortless-omni-prompt`** carries a concrete removal target of
  **2026-07-01** (deprecated 2026-04-05).

### Notes for upgraders
- Run `bash install.sh --yes` after `git pull`. The installer will:
  1. Install the renamed skills (`effortless-orchestrator`,
     `effortless-magic-links`).
  2. Offer to remove the old installed copies (`effortless-claude`,
     `magic-links`) — accept the prompt.
  3. Still offer to clean up `effortless-omni-prompt` if you haven't
     already.
- `--symlink` users get the new content automatically once `git pull` lands.

---

## 2026-04-30 — License relicensed to MIT

- Repo relicensed from "Proprietary. All rights reserved." to MIT.
  See `LICENSE`.

## 2026-04-26 — `effortless-bases` + `magic-links` skills

- Added `effortless-bases` (the bases.effortlessapi.com flow) and
  `magic-links` (generic Postgres flow). Both opened with the
  "Magic-links is a notary, not a referee" axiom.

## 2026-04-05 — `effortless-omni-prompt` deprecated

- OMNI prompt generation merged with Playwright-driven OMNI automation
  into the unified `effortless-airtable-omni` skill. The old
  `effortless-omni-prompt` remained as a deprecation shim that the
  installer cleans up.

## Earlier

The repo went through several earlier shape shifts before this
changelog began:

- Monolithic skill split into modular `effortless-*` skills.
- Installer rewritten to discover skills dynamically and clean up
  deprecated ones.
- `effortless-bootstrap` (the "Shadle steps") and
  `effortless-leopold-loop` skills introduced.
- Windows install script added.

For the full archaeology, `git log` is authoritative.
