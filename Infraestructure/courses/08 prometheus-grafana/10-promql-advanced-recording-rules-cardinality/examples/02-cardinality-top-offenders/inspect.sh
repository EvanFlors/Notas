#!/usr/bin/env bash
# inspect.sh — hit the TSDB status endpoint and run cardinality queries.
# NOTE: deliberately no 'set -o pipefail' because jq/grep pipelines may short-circuit.
set -u

PROM_URL="${PROM_URL:-http://localhost:9090}"

if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl not installed."
  exit 0
fi

if ! curl -fsS -m 3 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  echo "SKIP: Prometheus not reachable at $PROM_URL"
  echo "      Try: PROM_URL=http://your-prom:9090 ./inspect.sh"
  exit 0
fi

echo "== Target Prometheus: $PROM_URL =="
echo

echo "== TSDB status (seriesCountByMetricName top 10) =="
if command -v jq >/dev/null 2>&1; then
  curl -fsS "$PROM_URL/api/v1/status/tsdb" \
    | jq -r '.data.seriesCountByMetricName[] | "  \(.name): \(.value)"' \
    | head -n 10
else
  echo "  (install jq for pretty output; dumping raw JSON)"
  curl -fsS "$PROM_URL/api/v1/status/tsdb" | head -c 2000
  echo
fi
echo

echo "== topk(5, count by (__name__)({__name__!=\"\"})) =="
Q='topk(5, count by (__name__) ({__name__!=""}))'
if command -v jq >/dev/null 2>&1; then
  curl -fsS --data-urlencode "query=$Q" "$PROM_URL/api/v1/query" \
    | jq -r '.data.result[] | "  \(.metric.__name__ // "<missing>"): \(.value[1])"'
else
  curl -fsS --data-urlencode "query=$Q" "$PROM_URL/api/v1/query"
  echo
fi
echo

echo "== rate(prometheus_tsdb_head_series_created_total[5m]) =="
Q2='rate(prometheus_tsdb_head_series_created_total[5m])'
if command -v jq >/dev/null 2>&1; then
  curl -fsS --data-urlencode "query=$Q2" "$PROM_URL/api/v1/query" \
    | jq -r '.data.result[] | "  \(.metric | tostring): \(.value[1])"'
else
  curl -fsS --data-urlencode "query=$Q2" "$PROM_URL/api/v1/query"
  echo
fi

echo
echo "OK: diagnostic complete."
