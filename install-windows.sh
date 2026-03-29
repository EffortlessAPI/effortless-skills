#!/bin/bash
# Install / Uninstall the Effortless Claude skills for Claude Code (Windows / Git Bash)
#
# Usage (run from Git Bash):
#   bash install-windows.sh              — interactive install (asks before overwriting)
#   bash install-windows.sh --yes        — non-interactive install (overwrite all)
#   bash install-windows.sh --uninstall  — remove installed skills
#
# Installs all effortless-* skills into %USERPROFILE%/.claude/skills/
# Each skill gets its own folder as required by Claude Code.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"

# Use USERPROFILE for Windows path, fall back to HOME
if [ -n "$USERPROFILE" ]; then
  # Convert Windows path (C:\Users\foo) to Git Bash path (/c/Users/foo)
  SKILLS_DEST="$(cd "$USERPROFILE" && pwd)/.claude/skills"
else
  SKILLS_DEST="$HOME/.claude/skills"
fi

# Dynamically discover all skill folders under skills/
SKILLS=()
for d in "$SKILLS_SRC"/*/; do
  [ -d "$d" ] && SKILLS+=("$(basename "$d")")
done

if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "ERROR: No skill folders found in $SKILLS_SRC"
  exit 1
fi

# ---------- parse flags ----------
MODE="install"
AUTO_YES=false

for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE="uninstall" ;;
    --yes|-y)    AUTO_YES=true ;;
    --help|-h)
      echo "Usage: bash install-windows.sh [--yes] [--uninstall]"
      echo ""
      echo "  (no flags)   Interactive install — asks before overwriting"
      echo "  --yes, -y    Non-interactive — overwrite without asking"
      echo "  --uninstall  Remove all installed effortless-* skills"
      echo "  --help, -h   Show this help"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (try --help)"
      exit 1
      ;;
  esac
done

# ---------- helpers ----------
# Human-readable modification time
mod_time() {
  if stat --version >/dev/null 2>&1; then
    stat -c '%y' "$1" 2>/dev/null | cut -d. -f1
  else
    date -r "$1" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown"
  fi
}

# Compare directory contents (returns 0 if identical)
dirs_identical() {
  diff -rq "$1" "$2" >/dev/null 2>&1
}

ask_yes_no() {
  local prompt="$1" default="${2:-n}"
  if $AUTO_YES; then
    return 0
  fi
  while true; do
    printf "%s [y/n]: " "$prompt"
    read -r answer
    case "${answer:-$default}" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *)     echo "  Please answer y or n." ;;
    esac
  done
}

# ================================================================
#  UNINSTALL
# ================================================================
if [ "$MODE" = "uninstall" ]; then
  echo ""
  echo "=== Effortless Claude Skills — Uninstall (Windows) ==="
  echo ""
  echo "This will remove the following skills from $SKILLS_DEST:"
  echo ""

  found=0
  for skill in "${SKILLS[@]}"; do
    dest="$SKILLS_DEST/$skill"
    if [ -e "$dest" ]; then
      ((++found))
      echo "  $skill  (modified $(mod_time "$dest/SKILL.md"))"
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "  (none found — nothing to uninstall)"
    echo ""
    exit 0
  fi

  echo ""
  if ! ask_yes_no "Remove these $found skill(s)?"; then
    echo "Aborted."
    exit 0
  fi

  removed=0
  for skill in "${SKILLS[@]}"; do
    dest="$SKILLS_DEST/$skill"
    if [ -e "$dest" ]; then
      rm -r "$dest"
      echo "  Removed: $skill"
      ((++removed))
    fi
  done

  echo ""
  echo "Done — removed $removed skill(s)."
  echo "Changes take effect in your next Claude Code session."
  echo ""
  exit 0
fi

# ================================================================
#  INSTALL
# ================================================================
echo ""
echo "=== Effortless Claude Skills — Install (Windows) ==="
echo ""
echo "Source:      $SKILLS_SRC"
echo "Destination: $SKILLS_DEST"
echo "Mode:        copy"
echo ""

# Pre-flight: show what will happen for each skill
echo "--- Plan ---"
echo ""
actions_needed=0

for skill in "${SKILLS[@]}"; do
  src="$SKILLS_SRC/$skill"
  dest="$SKILLS_DEST/$skill"

  if [ ! -d "$src" ]; then
    echo "  SKIP  $skill — source not found at $src"
    continue
  fi

  if [ ! -e "$dest" ]; then
    echo "  NEW   $skill — will be installed"
    ((++actions_needed))
  elif dirs_identical "$src" "$dest"; then
    echo "  OK    $skill — installed copy is identical (no change needed)"
  else
    src_time="$(mod_time "$src/SKILL.md")"
    dest_time="$(mod_time "$dest/SKILL.md")"
    echo "  UPDATE $skill — content differs"
    echo "           source modified:    $src_time"
    echo "           installed modified: $dest_time"
    ((++actions_needed))
  fi
done

echo ""

if [ "$actions_needed" -eq 0 ]; then
  echo "Everything is up to date — nothing to do."
  echo ""
  exit 0
fi

if ! $AUTO_YES; then
  echo "$actions_needed skill(s) to install or update."
  echo ""
fi

# ---------- perform install ----------
mkdir -p "$SKILLS_DEST"

installed=0
updated=0
skipped=0

for skill in "${SKILLS[@]}"; do
  src="$SKILLS_SRC/$skill"
  dest="$SKILLS_DEST/$skill"

  if [ ! -d "$src" ]; then
    continue
  fi

  # Already up to date?
  if [ -d "$dest" ] && dirs_identical "$src" "$dest"; then
    continue
  fi

  # Destination exists and differs — ask before overwriting
  is_new=true
  if [ -e "$dest" ]; then
    is_new=false

    if ! $AUTO_YES; then
      existing_desc="modified $(mod_time "$dest/SKILL.md")"
      echo "  $skill already exists ($existing_desc)"
      if ! ask_yes_no "  Overwrite with source (modified $(mod_time "$src/SKILL.md"))?"; then
        echo "  Skipped."
        ((++skipped))
        continue
      fi
    fi

    rm -r "$dest"
  fi

  cp -R "$src" "$dest"

  if $is_new; then
    echo "  Installed: $skill"
    ((++installed))
  else
    echo "  Updated:   $skill"
    ((++updated))
  fi
done

# ---------- summary ----------
echo ""
echo "--- Summary ---"
echo ""
[ "$installed" -gt 0 ] && echo "  Installed: $installed new skill(s)"
[ "$updated" -gt 0 ]   && echo "  Updated:   $updated skill(s)"
[ "$skipped" -gt 0 ]   && echo "  Skipped:   $skipped skill(s) (kept existing)"
[ "$installed" -eq 0 ] && [ "$updated" -eq 0 ] && [ "$skipped" -eq 0 ] && echo "  No changes made."
echo ""
echo "Skills installed to: $SKILLS_DEST/"
echo ""
for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DEST/$skill"
  if [ -e "$dest" ]; then
    # Extract first line of description from SKILL.md frontmatter
    desc=""
    skill_md="$SKILLS_SRC/$skill/SKILL.md"
    if [ -f "$skill_md" ]; then
      # Handle both inline (description: text) and folded (description: >\n  text) YAML
      desc="$(awk '/^description:/{
        sub(/^description: */, "");
        if ($0 == ">" || $0 == "|" || $0 == "") { getline; sub(/^  */, ""); }
        print; exit
      }' "$skill_md" | cut -c1-60)"
    fi
    if [ -n "$desc" ]; then
      printf "  %-25s — %s\n" "$skill" "$desc"
    else
      echo "  $skill"
    fi
  fi
done
echo ""
echo "Skills will activate automatically in your next Claude Code session."
echo "To uninstall: bash install-windows.sh --uninstall"
echo ""
