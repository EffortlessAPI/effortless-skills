#!/bin/bash
# view-timings.sh -- read every vw_* view whole and time it; name the slow ones.
#
#   bash ~/.claude/skills/effortless-diagnostics/view-timings.sh <postgres-url> [slow-ms=1500] [schema=public]
#   bash ~/.claude/skills/effortless-diagnostics/view-timings.sh <postgres-url> --columns vw_name
#
# The first form prints each view slower than slow-ms (and any that fail), then
# the five slowest, and exits 1 when any is slow. The second times one view
# column by column, slowest first: the slow column is the expensive sub-DAG.
#
# Every row is turned into text, so every column is evaluated: a bare
# count(*) lets Postgres skip the calc functions and always looks fast.
# On mock data (a few dozen rows a table) a view over 1-2 s is a model
# problem; see SKILL.md, "Slow views".

set -u
URL="${1:?usage: view-timings.sh <postgres-url> [slow-ms] [schema] | <postgres-url> --columns vw_name}"
now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then local t="${EPOCHREALTIME/[.,]/}"; echo "${t:0:${#t}-3}"; return; fi
  local d; d=$(date +%s%3N 2>/dev/null)
  case "$d" in ''|*[!0-9]*) perl -MTime::HiRes=time -e 'printf "%d", time * 1000';; *) echo "$d";; esac
}
q() { psql "$URL" -X -q -A -t -v ON_ERROR_STOP=1 -c "$1"; }

if [ "${2:-}" = "--columns" ]; then
  V="${3:?view name}"
  case "$V" in *[!a-zA-Z0-9_]*) echo "bad view name" >&2; exit 2;; esac
  for c in $(q "SELECT column_name FROM information_schema.columns WHERE table_name = '$V' ORDER BY ordinal_position"); do
    s=$(now_ms); q "SET statement_timeout = 60000; SELECT sum(length(\"$c\"::text)) FROM $V" >/dev/null 2>&1; e=$(now_ms)
    printf '%8d ms  %s\n' "$((e - s))" "$c"
  done | sort -rn
  exit 0
fi

SLOW="${2:-1500}"; SCHEMA="${3:-public}"
case "$SCHEMA" in *[!a-zA-Z0-9_]*) echo "bad schema name" >&2; exit 2;; esac
out=$(mktemp)
for v in $(q "SELECT table_name FROM information_schema.views WHERE table_schema = '$SCHEMA' AND table_name LIKE 'vw%' ORDER BY 1"); do
  case "$v" in vw_*) ;; *) continue;; esac
  s=$(now_ms)
  if r=$(q "SET statement_timeout = $((SLOW * 20)); SELECT count(*) FROM (SELECT length(t::text) AS l FROM $SCHEMA.$v t) x WHERE l >= 0" 2>&1); then err=""; else err="${r//$'\n'/ }"; r=""; fi
  e=$(now_ms)
  printf '%d\t%s\t%s\t%s\n' "$((e - s))" "$v" "$(printf '%s' "$r" | tail -n1)" "$err" >> "$out"
done
sort -rn "$out" -o "$out"
n=$(wc -l < "$out" | tr -d ' ')
slow=$(awk -F'\t' -v t="$SLOW" '$1 > t || $4 != ""' "$out")
echo "$n views; slowest:"
head -5 "$out" | awk -F'\t' '{ printf "  %6d ms  %s (%s rows)%s\n", $1, $2, ($3 == "" ? "?" : $3), ($4 == "" ? "" : "  " $4) }'
rm -f "$out"
if [ -n "$slow" ]; then
  echo "SLOW (over $SLOW ms) or FAILING:"
  printf '%s\n' "$slow" | awk -F'\t' '{ printf "  %6d ms  %s%s\n", $1, $2, ($4 == "" ? "" : "  " $4) }'
  echo "Next: view-timings.sh <url> --columns <view> to find the column, then cache its sub-DAG at the parent (SKILL.md, Slow views)."
  exit 1
fi
echo "No view over $SLOW ms."
