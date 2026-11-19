#!/bin/bash
# After a commit or a pull that touched skills/, install them here: the copies under ~/.claude/skills are what every
# local agent reads, so a commit that is not installed is a skill nobody on this machine uses (2026-11-19).
root="$(git rev-parse --show-toplevel)"
[ -d "$HOME/.claude/skills" ] || exit 0
git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | grep -q '^skills/' || [ "$1" = "force" ] || exit 0
bash "$root/install.sh" --yes >/dev/null 2>&1
bash "$root/scripts/skills-in-sync.sh" >/dev/null || echo "WARNING: the installed effortless skills do not match this clone (bash $root/scripts/skills-in-sync.sh)"
