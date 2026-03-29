#!/usr/bin/env bash
# lint-skills.sh — structural lint for the Effortless Claude skill suite.
#
# Verifies, for every skills/<name>/SKILL.md:
#   1. The file exists.
#   2. It has YAML frontmatter (opens with --- and contains a closing ---).
#   3. The `name:` field matches the directory name.
#   4. There is a non-empty `description:` field (folded or inline).
#   5. There is an `audience:` field (customer | general).
#   6. If `deprecated: true`, then `replaced_by:` is also present.
#
# Also verifies:
#   - DEPRECATED_SKILLS.md parses cleanly with the same logic install.sh uses.
#   - Every entry in DEPRECATED_SKILLS.md is NOT a current skill folder.
#
# Exit 0 on clean lint, 1 on any failure. Suitable for CI / pre-commit.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
DEPRECATED_MD="$SCRIPT_DIR/DEPRECATED_SKILLS.md"

errors=0
checked=0

red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

fail() {
  red "  FAIL: $1"
  errors=$((errors + 1))
}

extract_yaml_field() {
  # $1 = file, $2 = field name. Handles inline (`name: foo`) and folded (`name: >\n  foo`).
  awk -v field="$2" '
    BEGIN { in_fm = 0; want = 0 }
    /^---$/ { in_fm = !in_fm; if (!in_fm) exit; next }
    !in_fm { next }
    {
      if (want) {
        sub(/^[[:space:]]+/, "");
        if ($0 == "") { want = 0; next }
        print; want = 0; exit
      }
      if ($0 ~ "^"field":") {
        v = $0
        sub("^"field":[[:space:]]*", "", v)
        if (v == ">" || v == "|" || v == "") { want = 1; next }
        print v; exit
      }
    }
  ' "$1"
}

# ---- skill-by-skill checks ----
echo "Linting skills under $SKILLS_DIR ..."
for d in "$SKILLS_DIR"/*/; do
  [ -d "$d" ] || continue
  skill="$(basename "$d")"
  md="$d/SKILL.md"
  checked=$((checked + 1))

  if [ ! -f "$md" ]; then
    fail "$skill: missing SKILL.md"
    continue
  fi

  if ! head -1 "$md" | grep -q '^---$'; then
    fail "$skill: SKILL.md does not start with '---' frontmatter delimiter"
    continue
  fi

  # Find the closing --- (must exist past line 1).
  if ! awk 'NR>1 && /^---$/ {found=1; exit} END {exit !found}' "$md"; then
    fail "$skill: SKILL.md frontmatter is not closed (no second '---')"
    continue
  fi

  name="$(extract_yaml_field "$md" name | tr -d '"')"
  if [ -z "$name" ]; then
    fail "$skill: missing or empty 'name:' in frontmatter"
  elif [ "$name" != "$skill" ]; then
    fail "$skill: frontmatter name '$name' does not match directory '$skill'"
  fi

  desc="$(extract_yaml_field "$md" description)"
  if [ -z "$desc" ]; then
    fail "$skill: missing or empty 'description:' in frontmatter"
  fi

  audience="$(extract_yaml_field "$md" audience)"
  if [ -z "$audience" ]; then
    fail "$skill: missing 'audience:' (expected 'customer' or 'general')"
  elif [ "$audience" != "customer" ] && [ "$audience" != "general" ]; then
    fail "$skill: audience '$audience' is not 'customer' or 'general'"
  fi

  deprecated="$(extract_yaml_field "$md" deprecated)"
  if [ "$deprecated" = "true" ]; then
    replaced_by="$(extract_yaml_field "$md" replaced_by)"
    if [ -z "$replaced_by" ]; then
      fail "$skill: deprecated:true but no 'replaced_by:' field"
    fi
  fi
done

# ---- DEPRECATED_SKILLS.md parser sanity ----
echo
if [ -f "$DEPRECATED_MD" ]; then
  echo "Verifying DEPRECATED_SKILLS.md parses cleanly ..."
  bad_dep=0
  while IFS='|' read -r _ skill _ ; do
    skill="$(echo "$skill" | xargs)"
    [[ "$skill" =~ ^-+$ ]] && continue
    [[ "$skill" == "Deprecated Skill" ]] && continue
    [ -z "$skill" ] && continue

    # If a folder still exists for the deprecated name, it MUST be a
    # deprecation shim (frontmatter has `deprecated: true`). Otherwise
    # the deprecation registry collides with a live skill.
    if [ -d "$SKILLS_DIR/$skill" ]; then
      shim_md="$SKILLS_DIR/$skill/SKILL.md"
      shim_dep="$(extract_yaml_field "$shim_md" deprecated)"
      if [ "$shim_dep" != "true" ]; then
        fail "DEPRECATED_SKILLS.md: '$skill' is listed as deprecated but live skill folder $SKILLS_DIR/$skill is not marked 'deprecated: true'"
        bad_dep=$((bad_dep + 1))
      fi
    fi
  done < <(grep '^|' "$DEPRECATED_MD" | tail -n +3)

  if [ "$bad_dep" -eq 0 ]; then
    green "  OK: DEPRECATED_SKILLS.md is consistent with skills/."
  fi
else
  yellow "  (no DEPRECATED_SKILLS.md found — skipping deprecation check)"
fi

# ---- summary ----
echo
echo "Checked $checked skill(s). Errors: $errors"
if [ "$errors" -eq 0 ]; then
  green "lint passed."
  exit 0
else
  red "lint FAILED."
  exit 1
fi
