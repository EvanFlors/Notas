#!/usr/bin/env bash
# Validate cap-13-03-measure-dora.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `cmd | grep -q ...` that may trigger SIGPIPE on the left-hand side when
# grep exits early. pipefail would turn those into spurious failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-13-03}}"
EVENTS="$BASE/events.json"
REPORT="$BASE/report.json"
passed=0
failed=0
report=""

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available"
  exit 0
fi

echo "== Validating cap-13-03-measure-dora under $BASE =="
if [ ! -f "$EVENTS" ]; then
  echo "FAIL: $EVENTS missing. Fix the broken file first."
  exit 1
fi

check_valid_json() {
  local name="events.json is valid JSON"
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$EVENTS" >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

check_three_success_deploys() {
  local name=">=3 successful prod deploys for capstone-app"
  local n
  n="$(python3 -c "
import json,sys
events = json.load(open(sys.argv[1]))
print(sum(1 for e in events
          if e.get('type') == 'deploy'
          and e.get('service') == 'capstone-app'
          and e.get('env') == 'prod'
          and e.get('status') == 'success'))
" "$EVENTS" 2>/dev/null || echo 0)"
  if [ "${n:-0}" -ge 3 ]; then
    report+="$name: OK ($n)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (got $n)\n"; failed=$((failed+1))
  fi
}

check_incident_linked() {
  local name="Incident references an existing deploy id"
  local ok
  ok="$(python3 -c "
import json,sys
events = json.load(open(sys.argv[1]))
deploy_ids = {e['id'] for e in events if e.get('type') == 'deploy'}
inc = [e for e in events if e.get('type') == 'incident'
       and e.get('caused_by_deploy_id') in deploy_ids]
print('yes' if inc else 'no')
" "$EVENTS" 2>/dev/null || echo no)"
  if [ "$ok" = "yes" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

check_report_bucket() {
  local name="report.json has valid bucket"
  if [ ! -f "$REPORT" ]; then
    report+="$name: FAIL — $REPORT missing (run compute_dora.py)\n"
    failed=$((failed+1)); return
  fi
  local bucket
  bucket="$(python3 -c "
import json,sys
print(json.load(open(sys.argv[1])).get('bucket', ''))
" "$REPORT" 2>/dev/null || echo "")"
  case "$bucket" in
    ELITE|HIGH|MEDIUM|LOW)
      report+="$name: OK ($bucket)\n"; passed=$((passed+1)) ;;
    *)
      report+="$name: FAIL (bucket='$bucket')\n"; failed=$((failed+1)) ;;
  esac
}

check_valid_json
check_three_success_deploys
check_incident_linked
check_report_bucket

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/4 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
