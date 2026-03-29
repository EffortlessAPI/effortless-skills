# Changelog

All notable changes to the Effortless Claude skill suite are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses date-based versioning rather than semver — each
release section is an ISO date.

## [Unreleased]

### Added
- **`effortless-setup-sql-server`** (new skill) — first-run setup for SQL Server
  substrate projects: install `rulebook-to-sql-server` from `/sql-server/`,
  patch `init-db.sh` connection defaults, register `-exec ./init-db.sh` in
  `effortless.json`, preflight `sqlcmd` + Docker MSSQL, disable Postgres
  spokes when switching substrates, and wire Express to the `mssql` driver
  (`@param` placeholders, boolean normalization, CAST for aggregates).
  Documents the generated `00`–`05` T-SQL layout, check-add idempotency, and
  the `03c-drop-security-policies.sql` workaround for RLS Msg 3729 on re-runs.
- **`effortless-publish-tool`** (new skill) — the supported path to **publish /
  push / deploy / release a new version of a transpiler tool** in
  `Versioned-Stable-SSoTme-Tools`. Documents `scripts/publish-tool.sh
  <transpilerId> <category>/<tool-name>`, how to fetch the `recXXXX` transpilerId
  from `/api/transpilers`, and — the thing that previously caused confusion —
  that the transpiler-server often runs on a **non-3000 port** (find it via
  `ps`/`lsof`, pass `API_BASE=http://localhost:<port>/api`) and that the Bash
  sandbox can make a live localhost server *look* down. Disambiguates
  `publish-tool.sh` (flips `[latest]` live) from `build-and-push-cpln-workload.sh`
  (build only) and from `effortless build` (consumes a published tool). Triggers
  on "publish/push/deploy/ship/release the tool".
- **Default RuleSpeak on rulebook creation** — `effortless-rulespeak`,
  `effortless-init` (Step 3.5), `effortless-bootstrap` (Step 10.5),
  `effortless-demo-app` (bootstrap step 7), and `effortless-setup-postgres`
  (Step 2.5) now require installing `rulebook-to-rulespeak` and generating
  `rulespeak/rulespeak.html` (+ `.md`) whenever a rulebook hub is first authored.
  Agents should not wait for the user to ask for plain-English rules.

### Changed
- **`effortless-rulespeak`** — scope expanded from demo/POC-only to default on
  any "create/write a rulebook" task; documents `rulespeak.html` as the primary
  human deliverable.
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
