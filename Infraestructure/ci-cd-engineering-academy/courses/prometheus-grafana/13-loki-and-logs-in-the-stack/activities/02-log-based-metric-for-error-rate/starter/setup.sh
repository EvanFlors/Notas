#!/usr/bin/env bash
# Copy a skeleton dashboard.json + task README into a scratch dir.
set -eu

BASE="${1:-/tmp/obs13-lab02}"
mkdir -p "$BASE"

cat > "$BASE/dashboard.json" <<'JSON'
{
  "annotations": {"list": []},
  "editable": true,
  "schemaVersion": 39,
  "title": "API error rate (log-based) — INCOMPLETE",
  "uid": "obs13-lab02",
  "tags": ["obs-13", "log-based-metric"],
  "description": "",
  "time": {"from": "now-1h", "to": "now"},
  "templating": {"list": []},
  "panels": []
}
JSON

cat > "$BASE/README-task.md" <<'MD'
# Task

1. Fill the top-level `description` explaining this is a LOG-BASED metric and why.
2. Add Panel 1 (timeseries) titled "API error rate (log-based)" whose datasource is
   `{"type": "loki", "uid": "loki"}` and whose target `expr` is EXACTLY:

       sum(rate({app="api"} |= "ERROR" [5m]))

3. Add Panel 2 (table or barchart) with the top-5 paths with most errors.
4. Create `NOTES.md` next to this file answering the three design questions in README.md §5.2.
5. Run the validator.
MD

cat > "$BASE/NOTES.md" <<'MD'
# Design notes

TODO: answer the three questions from README §5.2.
MD

echo "Starter copied to $BASE"
echo "Edit $BASE/dashboard.json and $BASE/NOTES.md, then run the validator."
