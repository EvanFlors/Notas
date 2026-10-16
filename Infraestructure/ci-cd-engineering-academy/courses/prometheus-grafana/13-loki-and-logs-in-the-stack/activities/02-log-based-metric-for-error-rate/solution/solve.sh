#!/usr/bin/env bash
# Reference solution: write a complete dashboard.json + NOTES.md.
set -eu

BASE="${1:-/tmp/obs13-lab02}"
if [ ! -d "$BASE" ]; then
  echo "ERROR: run starter/setup.sh $BASE first"; exit 1
fi

cat > "$BASE/dashboard.json" <<'JSON'
{
  "annotations": {"list": []},
  "editable": true,
  "schemaVersion": 39,
  "title": "API error rate (log-based)",
  "uid": "obs13-lab02",
  "tags": ["obs-13", "log-based-metric"],
  "description": "LOG-BASED error rate for the `api` service. This dashboard derives a metric from Loki logs because the service is not instrumented. When direct instrumentation lands (counter api_requests_errors_total), prefer that and deprecate this panel.",
  "time": {"from": "now-1h", "to": "now"},
  "templating": {"list": []},
  "panels": [
    {
      "type": "timeseries",
      "title": "API error rate (log-based)",
      "datasource": {"type": "loki", "uid": "loki"},
      "targets": [
        {"refId": "A", "expr": "sum(rate({app=\"api\"} |= \"ERROR\" [5m]))"}
      ],
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
    },
    {
      "type": "table",
      "title": "Top 5 paths with errors (15m)",
      "datasource": {"type": "loki", "uid": "loki"},
      "targets": [
        {"refId": "A", "expr": "topk(5, sum by (path) (count_over_time({app=\"api\"} | json | level=\"error\" [15m])))"}
      ],
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
    }
  ]
}
JSON

cat > "$BASE/NOTES.md" <<'MD'
# Design notes

1. `rate()` normaliza por segundo y maneja counter resets implícitos de la
   evaluación de Loki; `count_over_time()/300` da la misma magnitud pero no
   compone bien con otras tasas. `rate()` es la primitiva estándar.
2. `sum by (instance) (rate({app="api"} |= "ERROR" [5m]))` da una serie por
   instancia; útil si una sola réplica carga los errores.
3. Para distinguir solo 5xx: `sum(rate({app="api"} | json | status=~"5.." [5m]))`
   — mejor que grep de "ERROR", y robusto si el log cambia de wording.
MD

echo "Solution written to $BASE"
