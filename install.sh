#!/bin/bash
# Install / Uninstall the Effortless Claude skills for Claude Code
#
# Usage:
#   bash install.sh              — interactive install (asks before overwriting)
#   bash install.sh --yes        — non-interactive install (overwrite all)
#   bash install.sh --symlink    — symlink skills instead of copying (for contributors)
#   bash install.sh --uninstall  — remove installed skills
#
# Installs all effortless-* skills into ~/.claude/skills/
# Each skill gets its own folder as required by Claude Code.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

# Deprecated skills — these were merged/replaced and should be cleaned up
# Parsed from DEPRECATED_SKILLS.md if it exists, or hardcoded as fallback
DEPRECATED_SKILLS=()
DEPRECATED_MD="$SCRIPT_DIR/DEPRECATED_SKILLS.md"
if [ -f "$DEPRECATED_MD" ]; then
  # Parse table rows: | skill-name | replaced-by | ...
  while IFS='|' read -r _ skill _ ; do
    skill="$(echo "$skill" | xargs)"  # trim whitespace
    # Skip header, separator, and empty lines
    [[ "$skill" =~ ^-+$ ]] && continue
    [[ "$skill" == "Deprecated Skill" ]] && continue
    [ -z "$skill" ] && continue
    DEPRECATED_SKILLS+=("$skill")
  done < <(grep '^|' "$DEPRECATED_MD" | tail -n +3)
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
USE_SYMLINK=false

for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE="uninstall" ;;
    --yes|-y)    AUTO_YES=true ;;
    --symlink)   USE_SYMLINK=true ;;
    --help|-h)
      echo "Usage: bash install.sh [--yes] [--symlink] [--uninstall]"
      echo ""
      echo "  (no flags)   Interactive install — asks before overwriting"
      echo "  --yes, -y    Non-interactive — overwrite without asking"
      echo "  --symlink    Symlink skills instead of copying (for contributors)"
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
# Human-readable modification time (cross-platform)
mod_time() {
  if stat --version >/dev/null 2>&1; then
    # GNU stat (Linux)
    stat -c '%y' "$1" 2>/dev/null | cut -d. -f1
  else
    # BSD stat (macOS)
    stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$1" 2>/dev/null
  fi
}

# Check if two paths resolve to the same file (symlink or hard link)
same_file() {
  local a b
  a="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  b="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
  [ "$a" = "$b" ]
}

# Check if dest is already a symlink pointing into our source tree
is_our_symlink() {
  local dest="$1" src="$2"
  [ -L "$dest" ] && {
    local target
    target="$(cd "$(dirname "$dest")" && readlink "$dest")"
    # resolve relative symlinks
    if [[ "$target" != /* ]]; then
      target="$(cd "$(dirname "$dest")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")"
    fi
    [ "$target" = "$src" ]
  }
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
  echo "=== Effortless Claude Skills — Uninstall ==="
  echo ""
  echo "This will remove the following skills from $SKILLS_DEST:"
  echo ""

  found=0
  for skill in "${SKILLS[@]}"; do
    dest="$SKILLS_DEST/$skill"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      ((++found))
      if [ -L "$dest" ]; then
        target="$(readlink "$dest")"
        echo "  $skill  (symlink -> $target)"
      else
        echo "  $skill  (copied, modified $(mod_time "$dest/SKILL.md"))"
      fi
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
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf "$dest"
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
echo "=== Effortless Claude Skills — Install ==="
echo ""
echo "Source:      $SKILLS_SRC"
echo "Destination: $SKILLS_DEST"
if $USE_SYMLINK; then
  echo "Mode:        symlink (skills stay linked to this repo)"
else
  echo "Mode:        copy"
fi
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

  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  NEW   $skill — will be installed"
    ((++actions_needed))
  elif is_our_symlink "$dest" "$src"; then
    if $USE_SYMLINK; then
      echo "  OK    $skill — already symlinked to this repo (no change needed)"
    else
      echo "  CHANGE $skill — currently symlinked here; will replace with copy"
      ((++actions_needed))
    fi
  elif [ -L "$dest" ]; then
    target="$(readlink "$dest")"
    echo "  CHANGE $skill — symlinked to $target; will replace"
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
  if $USE_SYMLINK && is_our_symlink "$dest" "$src"; then
    continue
  fi
  if ! $USE_SYMLINK && [ ! -L "$dest" ] && [ -d "$dest" ] && dirs_identical "$src" "$dest"; then
    continue
  fi

  # Destination exists and differs — ask before overwriting
  is_new=true
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    is_new=false

    if ! $AUTO_YES; then
      # Build a description of what's there now
      if [ -L "$dest" ]; then
        existing_desc="symlink -> $(readlink "$dest")"
      else
        existing_desc="copied, modified $(mod_time "$dest/SKILL.md")"
      fi

      echo "  $skill already exists ($existing_desc)"
      if ! ask_yes_no "  Overwrite with $(if $USE_SYMLINK; then echo 'symlink'; else echo 'copy from'; fi) source (modified $(mod_time "$src/SKILL.md"))?"; then
        echo "  Skipped."
        ((++skipped))
        continue
      fi
    fi

    rm -rf "$dest"
  fi

  if $USE_SYMLINK; then
    ln -s "$src" "$dest"
  else
    cp -R "$src" "$dest"
  fi

  if $is_new; then
    echo "  Installed: $skill"
    ((++installed))
  else
    echo "  Updated:   $skill"
    ((++updated))
  fi
done

# ---------- clean up deprecated skills ----------
deprecated_removed=0
if [ "${#DEPRECATED_SKILLS[@]}" -gt 0 ]; then
  for dep_skill in "${DEPRECATED_SKILLS[@]}"; do
    dep_dest="$SKILLS_DEST/$dep_skill"
    if [ -e "$dep_dest" ] || [ -L "$dep_dest" ]; then
      # Check it's not also a current skill (safety guard)
      is_current=false
      for skill in "${SKILLS[@]}"; do
        [ "$skill" = "$dep_skill" ] && is_current=true && break
      done
      if $is_current; then
        continue
      fi

      echo ""
      echo "  DEPRECATED: $dep_skill is still installed but has been replaced."
      if ask_yes_no "  Remove deprecated skill '$dep_skill'?"; then
        rm -rf "$dep_dest"
        echo "  Removed: $dep_skill"
        ((++deprecated_removed))
      else
        echo "  Kept: $dep_skill"
      fi
    fi
  done
fi

# ---------- summary ----------
echo ""
echo "--- Summary ---"
echo ""
[ "$installed" -gt 0 ] && echo "  Installed: $installed new skill(s)"
[ "$updated" -gt 0 ]   && echo "  Updated:   $updated skill(s)"
[ "$skipped" -gt 0 ]            && echo "  Skipped:    $skipped skill(s) (kept existing)"
[ "$deprecated_removed" -gt 0 ] && echo "  Deprecated: $deprecated_removed removed"
[ "$installed" -eq 0 ] && [ "$updated" -eq 0 ] && [ "$skipped" -eq 0 ] && [ "$deprecated_removed" -eq 0 ] && echo "  No changes made."
echo ""
echo "Skills installed to: $SKILLS_DEST/"
echo ""
for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DEST/$skill"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
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
echo "To uninstall: bash $0 --uninstall"
echo ""
