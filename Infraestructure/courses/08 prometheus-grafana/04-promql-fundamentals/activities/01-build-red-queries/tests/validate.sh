#!/usr/bin/env bash
# Validate the RED trio in starter/queries.promql.
#
# Strategy:
#   1. Structural checks: no leftover TODOs, 3 required patterns present.
#   2. If `promtool` is available, syntax-check the queries as recording rules.
#   3. If a Prometheus server is reachable, additionally query each expression.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which produces SIGPIPE (exit 141) in the upstream
# command when grep exits early on a match. pipefail would spuriously flag
# those pipelines as failures.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
QUERIES="$HERE/../starter/queries.promql"
PROM_URL="${PROM_URL:-http://localhost:9090}"
SCRATCH="$(mktemp -d /tmp/promql-01-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

passed=0
failed=0
report=""

if [ ! -f "$QUERIES" ]; then
  echo "FAIL: $QUERIES not found" >&2
  exit 1
fi

# 1. No TODOs left on actual query lines (comments starting with # TODO: are okay to leave,
# but the pattern `TODO:` inside a non-comment line fails).
# We check: lines that are NOT comments AND contain 'TODO'.
noncomment_todo=$(grep -nvE '^[[:space:]]*#' "$QUERIES" | grep -c 'TODO' || true)
if [ "$noncomment_todo" -eq 0 ]; then
  report+="Check 1 (no leftover TODO on query lines): OK\n"
  passed=$((passed+1))
else
  report+="Check 1: FAIL — hay $noncomment_todo líneas sin resolver con TODO\n"
  failed=$((failed+1))
fi

# 2. Required patterns.
check_pattern() {
  local label="$1" pattern="$2"
  if grep -Eq "$pattern" "$QUERIES"; then
    report+="Check: $label: OK\n"; passed=$((passed+1))
  else
    report+="Check: $label: FAIL — patrón '$pattern' no encontrado\n"
    failed=$((failed+1))
  fi
}

check_pattern "RATE present"     'rate\(http_requests_total\[[0-9]+[smh]\]\)'
check_pattern "ERRORS ratio"     'code=~"5\.\."'
check_pattern "DURATION p95"     'histogram_quantile\([[:space:]]*0\.95'
check_pattern "le in by for p95" 'by[[:space:]]*\([^)]*\ble\b[^)]*\)'

# 3. promtool syntax check if available.
if command -v promtool >/dev/null 2>&1; then
  python3 - "$QUERIES" > "$SCRATCH/rules.yaml" <<'PY'
import sys, pathlib
lines = pathlib.Path(sys.argv[1]).read_text().splitlines()
groups = []
buf = []
for ln in lines + [""]:
    s = ln.rstrip()
    if not s or s.lstrip().startswith("#"):
        if buf:
            groups.append(" ".join(x.strip() for x in buf))
            buf = []
        continue
    buf.append(s)
print("groups:")
print("  - name: red")
print("    rules:")
for i, q in enumerate(groups, 1):
    print(f"      - record: red:q{i}")
    print(f"        expr: {q}")
PY
  if promtool check rules "$SCRATCH/rules.yaml" >"$SCRATCH/pt.log" 2>&1; then
    report+="Check: promtool syntax: OK\n"; passed=$((passed+1))
  else
    report+="Check: promtool syntax: FAIL\n"
    report+="$(cat "$SCRATCH/pt.log")\n"
    failed=$((failed+1))
  fi
else
  report+="Check: promtool syntax: SKIP (promtool not installed)\n"
fi

# 4. live query if server reachable.
if command -v curl >/dev/null 2>&1 \
   && curl -sS -m 2 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  report+="Check: live query against $PROM_URL: attempting\n"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in '#'*) continue;; esac
    resp="$(curl -sS -G --data-urlencode "query=$line" "$PROM_URL/api/v1/query" || echo '')"
    if echo "$resp" | grep -q '"status":"success"'; then
      :
    else
      report+="  live FAIL for: $line\n"
      failed=$((failed+1))
    fi
  done < "$QUERIES"
else
  report+="Check: live query: SKIP (no Prometheus at $PROM_URL)\n"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed check(s) OK, $failed FAIL."
[ "$failed" -eq 0 ] || exit 1
exit 0
