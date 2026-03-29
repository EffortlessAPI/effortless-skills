#!/usr/bin/env bash
# lint-skills-magic-links.sh — plan 03 §8 lint for the magic-links refactor.
#
# Flags any skill SKILL.md or REFERENCE.md that mentions
#   current_setting('app.jwt_*')
#   current_setting('request.jwt.…')
# OUTSIDE an explicit anti-pattern / DO-NOT callout. The forbidden
# patterns are still allowed in documentation that is clearly marked as
# "the wrong way" — what we don't want is skills accidentally teaching
# the v1 GUC-cache pattern as if it were correct.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HERE/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "lint: cannot find skills/ at $SKILLS_DIR"
  exit 1
fi

# All file:lineno pairs that mention the forbidden patterns. Use -n for
# line numbers, -H to always include filename, --include to scope.
matches=$(grep -RHnE "current_setting\\('(app\\.jwt|request\\.jwt)" \
            --include='*.md' "$SKILLS_DIR" 2>/dev/null || true)

if [ -z "$matches" ]; then
  echo "lint: no skill mentions current_setting('app.jwt_*'). PASS."
  exit 0
fi

echo "lint: found references — verifying each is inside an anti-pattern callout..."

bad_file="$(mktemp)"
trap 'rm -f "$bad_file"' EXIT

# Use awk to inspect each match independently (portable; no mapfile).
printf '%s\n' "$matches" | awk -F: -v badfile="$bad_file" '
  {
    file = $1
    lineno = $2 + 0
    if (file == "" || lineno == 0) next
    start = (lineno > 20) ? lineno - 20 : 1
    end = lineno + 5
    cmd = "awk -v s=" start " -v e=" end " \"NR>=s && NR<=e\" \"" file "\" 2>/dev/null | grep -qiE \"anti-pattern|do-?not|v1 GUC-cache|forbidden|wrong way\""
    if (system(cmd) != 0) {
      print "  FAIL  " file ":" lineno "  current_setting reference outside anti-pattern callout"
      print file ":" lineno >> badfile
    }
  }
'

if [ -s "$bad_file" ]; then
  echo "lint: FAIL"
  exit 1
fi

echo "lint: all references are inside anti-pattern callouts. PASS."
