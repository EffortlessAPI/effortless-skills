#!/usr/bin/env bash
#
# migrate-project-metadata.sh
#
# Moves Claude Code per-project metadata from the old GUID-based my-projects
# path to the short ~/development path, for projects that have been relocated.
#
#   old: /Users/eejai42/effortlessapi-app-root/users/user_ee42ai73-.../my-projects/<name>
#   new: /Users/eejai42/development/<name>
#
# Claude Code keys project metadata by the mangled absolute path (slashes and
# underscores -> dashes), so a moved project loses its memories, session
# transcripts, and per-project settings until those keys are renamed.
#
# What it moves, per project:
#   1. ~/.claude/projects/<mangled>/          memory/, session .jsonl, sidecars
#   2. ~/.claude.json  projects["<abs path>"] per-project settings + history
#
# Usage:
#   ./migrate-project-metadata.sh              # dry run (default)
#   ./migrate-project-metadata.sh --apply      # actually move
#   ./migrate-project-metadata.sh --apply foo  # only project "foo"
#
set -euo pipefail

HOME_DIR="${HOME}"
OLD_ROOT="${HOME_DIR}/effortlessapi-app-root/users/user_ee42ai73-18a9-47d5-8f99-954b00f6c041/my-projects"
NEW_ROOT="${HOME_DIR}/development"
PROJECTS_DIR="${HOME_DIR}/.claude/projects"
CLAUDE_JSON="${HOME_DIR}/.claude.json"

APPLY=0
ONLY=""
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --help|-h) sed -n '2,25p' "$0"; exit 0 ;;
    *) ONLY="$arg" ;;
  esac
done

# Claude mangles an absolute path into a directory name by replacing every
# character that is not [A-Za-z0-9] with a dash.
mangle() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

if [ "$APPLY" -eq 1 ]; then
  echo "MODE: APPLY (changes will be made)"
else
  echo "MODE: DRY RUN (no changes; pass --apply to execute)"
fi
echo

# Back up .claude.json once per run, before any mutation.
BACKUP=""
if [ "$APPLY" -eq 1 ]; then
  BACKUP="${CLAUDE_JSON}.bak-migrate-$(date +%Y%m%d-%H%M%S)"
  cp "$CLAUDE_JSON" "$BACKUP"
  echo "Backed up ${CLAUDE_JSON} -> ${BACKUP}"
  echo
fi

migrated=0
skipped=0

for new_path in "$NEW_ROOT"/*; do
  [ -d "$new_path" ] || continue
  name="$(basename "$new_path")"
  [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue

  old_path="${OLD_ROOT}/${name}"
  old_dir="${PROJECTS_DIR}/$(mangle "$old_path")"
  new_dir="${PROJECTS_DIR}/$(mangle "$new_path")"

  has_old_dir=0; [ -d "$old_dir" ] && has_old_dir=1
  has_json=0
  python3 - "$CLAUDE_JSON" "$old_path" <<'PY' && has_json=1
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if sys.argv[2] in d.get("projects", {}) else 1)
PY

  if [ "$has_old_dir" -eq 0 ] && [ "$has_json" -eq 0 ]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo "=== ${name}"

  # ---- 1. projects/<mangled> directory -------------------------------------
  if [ "$has_old_dir" -eq 1 ]; then
    n_all=$(find "$old_dir" -type f | wc -l | tr -d ' ')
    n_mem=$([ -d "$old_dir/memory" ] && find "$old_dir/memory" -type f | wc -l | tr -d ' ' || echo 0)
    echo "    dir : ${n_all} files (${n_mem} memory) at old path"

    if [ ! -d "$new_dir" ]; then
      echo "        -> move whole dir to $(basename "$new_dir")"
      [ "$APPLY" -eq 1 ] && mv "$old_dir" "$new_dir"
    else
      # New dir already exists (project used at its new path). Merge without
      # clobbering: copy only files the destination does not already have.
      echo "        -> new dir exists; merging non-conflicting files"
      while IFS= read -r src; do
        rel="${src#"$old_dir"/}"
        dst="${new_dir}/${rel}"
        if [ -e "$dst" ]; then
          echo "           skip (exists): ${rel}"
        else
          echo "           copy: ${rel}"
          if [ "$APPLY" -eq 1 ]; then
            mkdir -p "$(dirname "$dst")"
            cp -p "$src" "$dst"
          fi
        fi
      done < <(find "$old_dir" -type f)
      # Leave the old dir in place on merge; removing it is a separate call.
    fi
  else
    echo "    dir : none at old path"
  fi

  # ---- 2. .claude.json projects[] entry ------------------------------------
  if [ "$has_json" -eq 1 ]; then
    echo "    json: projects[\"${old_path}\"] present"
    echo "        -> rekey to \"${new_path}\""
    if [ "$APPLY" -eq 1 ]; then
      python3 - "$CLAUDE_JSON" "$old_path" "$new_path" <<'PY'
import json, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
projects = d.get("projects", {})
entry = projects.pop(old)
if new in projects:
    # Destination already has settings; keep them, fill only missing keys
    # and concatenate history so nothing is silently dropped.
    dest = projects[new]
    for k, v in entry.items():
        if k not in dest:
            dest[k] = v
        elif k == "history" and isinstance(v, list) and isinstance(dest.get(k), list):
            dest[k] = v + dest[k]
else:
    projects[new] = entry
with open(path, "w") as f:
    json.dump(d, f, indent=2)
PY
    fi
  else
    echo "    json: no entry at old path"
  fi

  migrated=$((migrated + 1))
  echo
done

echo "---"
echo "projects with metadata to migrate: ${migrated}"
echo "projects with nothing to migrate : ${skipped}"
if [ "$APPLY" -eq 0 ]; then
  echo
  echo "Dry run only. Re-run with --apply to execute."
else
  echo
  echo ".claude.json backup: ${BACKUP}"
  echo "NOTE: restart Claude Code so it re-reads .claude.json."
fi
