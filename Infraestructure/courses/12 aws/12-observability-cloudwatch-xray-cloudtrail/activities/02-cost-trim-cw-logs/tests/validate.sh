#!/usr/bin/env bash
# Structural validation for aws-12-02-cost-trim-cw-logs.
# Checks the 4 artifacts the student must produce in $BASE:
#   RETENTION.md, metric_filter.json, insights.md, alarm.json
# JSON files are validated with python3's stdlib `json`.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# pipe producers into `grep -q`, which can exit on SIGPIPE (141) when grep
# finds a match early. pipefail would mark these as spurious failures.
set -eu

BASE="${1:-/tmp/aws-12-cost}"
RET="$BASE/RETENTION.md"
MF="$BASE/metric_filter.json"
INS="$BASE/insights.md"
AL="$BASE/alarm.json"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Student must create it."
  exit 1
fi

# ---------------------------------------------------------------- RETENTION.md
if [ ! -f "$RET" ]; then
  echo "  FAIL $RET missing"
  fail=$((fail+1))
else
  if grep -qiE 'hot|warm|cold' "$RET"; then
    echo "  OK   RETENTION.md mentions tier (hot/warm/cold)"
  else
    echo "  FAIL RETENTION.md does not mention tier (hot/warm/cold)"
    fail=$((fail+1))
  fi
  if grep -qiE 'retention_in_days|retention[- ]in[- ]days|retentioninday' "$RET"; then
    echo "  OK   RETENTION.md mentions retention_in_days"
  else
    echo "  FAIL RETENTION.md does not mention retention_in_days"
    fail=$((fail+1))
  fi
  rows=$(grep -cE '^\|' "$RET")
  if [ "$rows" -ge 5 ]; then
    echo "  OK   RETENTION.md has a Markdown table ($rows pipe-lines; need header+sep+>=3 rows)"
  else
    echo "  FAIL RETENTION.md table too small ($rows pipe-lines; expected >=5)"
    fail=$((fail+1))
  fi
  bullets=0
  for n in 1 2 3; do
    if grep -Eq "^[[:space:]]*${n}\\." "$RET"; then
      bullets=$((bullets+1))
    fi
  done
  if [ "$bullets" -ge 3 ]; then
    echo "  OK   RETENTION.md has at least 3 numbered trade-off bullets"
  else
    echo "  FAIL RETENTION.md has only $bullets numbered bullets (expected >=3)"
    fail=$((fail+1))
  fi
fi

# ------------------------------------------------------------- metric_filter.json
if [ ! -f "$MF" ]; then
  echo "  FAIL $MF missing"
  fail=$((fail+1))
else
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('$MF'))" 2>/dev/null; then
      echo "  OK   metric_filter.json parses as JSON"
    else
      echo "  FAIL metric_filter.json is not valid JSON"
      fail=$((fail+1))
    fi
    if python3 -c "import json,sys; d=json.load(open('$MF')); assert 'filterPattern' in d and 'metricTransformations' in d and isinstance(d['metricTransformations'],list) and d['metricTransformations'] and 'metricName' in d['metricTransformations'][0] and 'metricNamespace' in d['metricTransformations'][0]" 2>/dev/null; then
      echo "  OK   metric_filter.json has filterPattern + metricTransformations[0].{metricName,metricNamespace}"
    else
      echo "  FAIL metric_filter.json missing required keys"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP python3 not available; skipping metric_filter.json structural check"
  fi
fi

# ------------------------------------------------------------------ insights.md
if [ ! -f "$INS" ]; then
  echo "  FAIL $INS missing"
  fail=$((fail+1))
else
  for kw in fields filter stats; do
    if grep -qE "(^|[^a-zA-Z])${kw}([^a-zA-Z]|$)" "$INS"; then
      echo "  OK   insights.md uses '$kw'"
    else
      echo "  FAIL insights.md does not use '$kw'"
      fail=$((fail+1))
    fi
  done
  if grep -qE 'bin\(|range|rango|time' "$INS"; then
    echo "  OK   insights.md scopes time (bin() or explicit time range mention)"
  else
    echo "  FAIL insights.md does not scope time"
    fail=$((fail+1))
  fi
fi

# ---------------------------------------------------------------------- alarm.json
if [ ! -f "$AL" ]; then
  echo "  FAIL $AL missing"
  fail=$((fail+1))
else
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('$AL'))" 2>/dev/null; then
      echo "  OK   alarm.json parses as JSON"
    else
      echo "  FAIL alarm.json is not valid JSON"
      fail=$((fail+1))
    fi
    if python3 -c "
import json,sys
d = json.load(open('$AL'))
needed_any = ('MetricName','AlarmRule')
missing = []
if 'AlarmName' not in d: missing.append('AlarmName')
if not any(k in d for k in needed_any): missing.append('MetricName|AlarmRule')
if 'MetricName' in d:
    for k in ('EvaluationPeriods','DatapointsToAlarm','Threshold','ComparisonOperator','TreatMissingData'):
        if k not in d: missing.append(k)
assert not missing, missing
" 2>/dev/null; then
      echo "  OK   alarm.json has required keys"
    else
      echo "  FAIL alarm.json missing required keys (see solution/REFERENCE.md)"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP python3 not available; skipping alarm.json structural check"
  fi
fi

# ------------------------------------------------------- secret / account check
for f in "$RET" "$MF" "$INS" "$AL"; do
  [ -f "$f" ] || continue
  if grep -qE 'AKIA[0-9A-Z]{16}|aws_secret_access_key' "$f"; then
    echo "  FAIL $f appears to contain static AWS credentials"
    fail=$((fail+1))
  fi
done
# Allow 123456789012 (AWS documentation example) but flag others.
for f in "$RET" "$MF" "$INS" "$AL"; do
  [ -f "$f" ] || continue
  for acct in $(grep -oE '\b[0-9]{12}\b' "$f" | sort -u); do
    if [ "$acct" != "123456789012" ]; then
      echo "  FAIL $f contains 12-digit id ($acct) that is not the AWS example"
      fail=$((fail+1))
    fi
  done
done

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
