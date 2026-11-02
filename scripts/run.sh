#!/usr/bin/env bash
# Runs every scenario: measure "before", apply the fix, measure "after".
# Usage: scripts/run.sh [scenario-prefix]     e.g. scripts/run.sh 01
set -euo pipefail
cd "$(dirname "$0")/.."

DB="${DATABASE_URL:-postgresql://lab:lab@localhost:5432/lab}"
RUNS="${RUNS:-5}"
q() { psql "$DB" -X -q -v ON_ERROR_STOP=1 "$@"; }

# bench <query.sql> <plan-output-file>  ->  prints median execution time (ms)
bench() {
  local sql plan times=()
  sql="$(sed -e 's/--.*$//' "$1" | tr '\n' ' ' | sed -e 's/;[[:space:]]*$//')"
  q -At -c "EXPLAIN (ANALYZE, BUFFERS) $sql" > /dev/null          # warm-up run
  for _ in $(seq "$RUNS"); do
    plan="$(q -At -c "EXPLAIN (ANALYZE, BUFFERS) $sql")"
    times+=("$(grep 'Execution Time' <<<"$plan" | awk '{print $3}')")
  done
  printf '%s\n' "$plan" > "$2"
  printf '%s\n' "${times[@]}" | sort -n | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}'
}

mkdir -p results
summary="results/summary.md"
{
  echo "| Scenario | Before (ms) | After (ms) | Speed-up |"
  echo "|---|---:|---:|---:|"
} > "$summary"

for dir in scenarios/${1:-}*/; do
  name="$(basename "$dir")"
  echo ">> $name"
  q -f "$dir/reset.sql"
  [ -f "$dir/setup.sql" ] && q -f "$dir/setup.sql"
  q -c "ANALYZE" 

  before="$(bench "$dir/query.sql" "results/${name}_before.txt")"
  [ -f "$dir/fix.sql" ] && q -f "$dir/fix.sql"
  q -c "ANALYZE"
  fixed="$dir/query.sql"; [ -f "$dir/query_fixed.sql" ] && fixed="$dir/query_fixed.sql"
  after="$(bench "$fixed" "results/${name}_after.txt")"

  speedup="$(awk -v b="$before" -v a="$after" 'BEGIN {printf "%.0fx", b / a}')"
  echo "   before: ${before} ms | after: ${after} ms | ${speedup}"
  echo "| ${name} | ${before} | ${after} | ${speedup} |" >> "$summary"
  q -f "$dir/reset.sql"
done

echo; cat "$summary"
