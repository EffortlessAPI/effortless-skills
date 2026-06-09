#!/bin/bash
# Build raw_skills.zip — a flat archive of every SKILL.md, renamed by folder.
#
# Usage:
#   bash build-raw-skills.sh
#
# Produces raw_skills.zip alongside skills.zip. The intermediate raw_skills/
# folder is a temp staging dir (gitignored) and is deleted after zipping.
#
# Each skills/<name>/SKILL.md becomes raw_skills/<name>.md
# (e.g. skills/effortless-schema/SKILL.md -> raw_skills/effortless-schema.md)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
STAGE="$SCRIPT_DIR/raw_skills"
ZIP="$SCRIPT_DIR/raw_skills.zip"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "ERROR: skills/ not found at $SKILLS_SRC"
  exit 1
fi

rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE"

count=0
for d in "$SKILLS_SRC"/*/; do
  name="$(basename "$d")"
  src="${d}SKILL.md"
  if [ ! -f "$src" ]; then
    echo "WARN: $name has no SKILL.md — skipping"
    continue
  fi
  cp "$src" "$STAGE/${name}.md"
  count=$((count + 1))
done

(cd "$SCRIPT_DIR" && zip -qr "$ZIP" "raw_skills")
rm -rf "$STAGE"

echo "Built $ZIP ($count skills)"
