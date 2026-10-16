#!/usr/bin/env bash
# demo.sh — list how many series your Prometheus has in classic histogram buckets.
# NOTE: deliberately no 'set -o pipefail' because jq/awk pipelines may short-circuit.
set -u

PROM_URL="${PROM_URL:-http://localhost:9090}"

if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl not installed."
  exit 0
fi

if ! curl -fsS -m 3 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  echo "SKIP: Prometheus not reachable at $PROM_URL"
  exit 0
fi

echo "== Classic histogram series count (metrics ending in _bucket) =="

Q='topk(20, count by (__name__) ({__name__=~".+_bucket"}))'

if command -v jq >/dev/null 2>&1; then
  curl -fsS --data-urlencode "query=$Q" "$PROM_URL/api/v1/query" \
    | jq -r '.data.result[] | "  \(.metric.__name__): \(.value[1])"'

  TOTAL=$(curl -fsS --data-urlencode 'query=count({__name__=~".+_bucket"})' \
    "$PROM_URL/api/v1/query" | jq -r '.data.result[0].value[1] // "0"')
  echo
  echo "  TOTAL classic bucket series: $TOTAL"
else
  echo "  (install jq for pretty output; dumping raw JSON)"
  curl -fsS --data-urlencode "query=$Q" "$PROM_URL/api/v1/query"
  echo
fi

echo
echo "OK: inspect complete. Each _bucket series is a classic histogram slot."
echo "    Native histograms would collapse those into 1 series per histogram."
