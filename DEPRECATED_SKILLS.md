# Deprecated Skills

Skills listed here have been merged or replaced. The installer will offer to
remove them from `~/.claude/skills/` if they are still installed.

The **Target Removal** column is a soft commitment: after that date the
deprecated entry can be dropped from this file (and the deprecated `SKILL.md`
shim can be deleted from the repo). Keep the entry around at least until then
so the installer continues to clean up old installed copies for users who
upgrade infrequently.

| Deprecated Skill | Replaced By | Deprecated On | Target Removal | Notes |
|------------------|-------------|---------------|----------------|-------|
| effortless-omni-prompt | effortless-airtable-omni | 2026-04-05 | 2026-07-01 | OMNI prompt generation merged with Playwright-driven OMNI automation. |
| magic-links | effortless-magic-links | 2026-04-30 | 2026-07-01 | Renamed to align with the `effortless-` prefix convention. Same content. |
| effortless-claude | effortless-orchestrator | 2026-04-30 | 2026-07-01 | Orchestrator skill renamed to remove the name collision with the parent repo. The repo is still `effortless-claude`; the orchestrator is now `effortless-orchestrator`. |
| effortless-install-cli | effortless-cli | 2026-05-01 | 2026-08-01 | CLI binary install/update merged into effortless-cli (Part 1 = install, Part 2 = use). One skill for the CLI artifact end-to-end. |
