#!/bin/bash
# Exit 0 when every skills/<name> of this clone is installed, identical, under $SKILLS_DEST (default ~/.claude/skills).
# Exit 1 and name each missing or stale skill otherwise. The installed copies are what every local agent reads.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${SKILLS_DEST:-$HOME/.claude/skills}"
bad=0
for d in "$ROOT"/skills/*/; do
  s="$(basename "$d")"
  if [ ! -d "$DEST/$s" ]; then echo "MISSING $s"; bad=1
  elif ! diff -rq "$d" "$DEST/$s" >/dev/null 2>&1; then echo "STALE   $s"; bad=1; fi
done
[ "$bad" = 0 ] && echo "installed skills match this clone" || echo "run: bash $ROOT/install.sh --yes"
exit "$bad"
