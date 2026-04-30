---
name: effortless-omni-prompt
description: >
  DEPRECATED — This skill has been merged into effortless-airtable-omni.
  Use effortless-airtable-omni instead for both OMNI prompt generation
  and Playwright-driven OMNI automation.
audience: customer
deprecated: true
deprecated_on: 2026-04-05
replaced_by: effortless-airtable-omni
removal_target: 2026-07-01
---

# DEPRECATED — scheduled for removal on 2026-07-01

This skill was deprecated on **2026-04-05** and will be removed from this
repo on or after **2026-07-01**. Until then, the installer will continue
to offer to clean up `~/.claude/skills/effortless-omni-prompt` for users
who upgrade infrequently.

It has been merged into **effortless-airtable-omni**, which combines:

- OMNI prompt generation (the two-part split pattern from this skill)
- Playwright-driven OMNI automation (lets Claude drive OMNI directly in a headed browser)

Please use `effortless-airtable-omni` instead.

To clean up, run:
```bash
rm -rf ~/.claude/skills/effortless-omni-prompt
```

Or re-run the installer, which will offer to remove deprecated skills:
```bash
bash install.sh --yes
```

## See also

- `effortless-airtable-omni` — the merged replacement.
- `DEPRECATED_SKILLS.md` (repo root) — the canonical deprecation registry.
