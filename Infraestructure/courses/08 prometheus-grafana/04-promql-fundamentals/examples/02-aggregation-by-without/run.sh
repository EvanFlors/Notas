#!/usr/bin/env bash
# Validate aggregation queries. Same tri-mode strategy as example 01.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
QUERIES="$HERE/queries.promql"
PROM_URL="${PROM_URL:-http://localhost:9090}"

if command -v curl >/dev/null 2>&1 \
   && curl -sS -m 2 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  echo "== Querying $PROM_URL =="
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue;; esac
    printf -- '--- %s\n' "$line"
    curl -sS -G --data-urlencode "query=$line" "$PROM_URL/api/v1/query" | head -c 400
    echo
  done < "$QUERIES"
  exit 0
fi

if command -v promtool >/dev/null 2>&1; then
  echo "== promtool syntax check =="
  TMP="$(mktemp -d /tmp/promql-ex02.XXXXXX)"
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
      # indent multiline-safe (single line here)
      echo "          $line"
    done < "$QUERIES"
  } > "$TMP/rules.yaml"
  promtool check rules "$TMP/rules.yaml"
  exit 0
fi

echo "SKIP: no Prometheus server at $PROM_URL and no promtool available."
exit 0
