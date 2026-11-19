#!/bin/bash
# The installed skills must follow the clone: an empty install fails, a fresh one passes, an edited skill fails by name.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T"; mkdir -p "$T/.claude/skills"
fail() { echo "FAIL: $1"; exit 1; }
out="$(bash "$ROOT/scripts/skills-in-sync.sh")" && fail "an empty install passed"
echo "$out" | grep -q "^MISSING effortless-go-live" || fail "missing skill not named: $out"
bash "$ROOT/install.sh" --yes >/dev/null || fail "install failed"
bash "$ROOT/scripts/skills-in-sync.sh" >/dev/null || fail "a fresh install did not pass"
echo "edited" >> "$T/.claude/skills/effortless-sql/SKILL.md"
out="$(bash "$ROOT/scripts/skills-in-sync.sh")" && fail "a stale skill passed"
echo "$out" | grep -q "^STALE   effortless-sql" || fail "stale skill not named: $out"
echo "ok"
