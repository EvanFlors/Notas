#!/usr/bin/env bash
# Validate / demo rate vs irate vs increase queries.
# SKIP gracefully if neither Prometheus server nor promtool is available.
# No pipefail: some pipes with `grep -q` would SIGPIPE and look like failures.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
QUERIES="$HERE/queries.promql"
PROM_URL="${PROM_URL:-http://localhost:9090}"

if [ ! -f "$QUERIES" ]; then
  echo "ERROR: queries.promql not found" >&2
  exit 1
fi

# Mode 1: Prometheus server reachable → query each expression.
if command -v curl >/dev/null 2>&1 \
   && curl -sS -m 2 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  echo "== Prometheus detected at $PROM_URL — running queries =="
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue;; esac
    printf -- '--- %s\n' "$line"
    curl -sS -G --data-urlencode "query=$line" "$PROM_URL/api/v1/query" \
      | head -c 500
    echo
  done < "$QUERIES"
  exit 0
fi

# Mode 2: promtool present → syntax check as a dummy rules file.
if command -v promtool >/dev/null 2>&1; then
  echo "== No Prometheus server; using promtool to syntax-check =="
  TMP="$(mktemp -d /tmp/promql-ex01.XXXXXX)"
  trap 'rm -rf "$TMP"' EXIT
  {
    echo "groups:"
    echo "  - name: demo"
    echo "    rules:"
    i=0
    while IFS= read -r line; do
      case "$line" in ''|'#'*) continue;; esac
      i=$((i+1))
      echo "      - record: demo:q$i"
      echo "        expr: |"
      echo "          $line"
    done < "$QUERIES"
  } > "$TMP/rules.yaml"
  promtool check rules "$TMP/rules.yaml"
  exit 0
fi

echo "SKIP: neither Prometheus server at $PROM_URL nor promtool are available."
echo "      Install promtool or start the obs-02 compose stack to run queries."
exit 0
