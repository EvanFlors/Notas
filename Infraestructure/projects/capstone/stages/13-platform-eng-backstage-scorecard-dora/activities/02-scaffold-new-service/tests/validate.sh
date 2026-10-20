#!/usr/bin/env bash
# Validate cap-13-02-scaffold-new-service.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `cmd | grep -q ...` that may trigger SIGPIPE on the left-hand side when
# grep exits early. pipefail would turn those into spurious failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-13-02}}"
SVC="$BASE/svc-reports"
passed=0
failed=0
report=""

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available"
  exit 0
fi
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "SKIP: PyYAML not installed"
  exit 0
fi

echo "== Validating cap-13-02-scaffold-new-service under $BASE =="
if [ ! -d "$SVC" ]; then
  echo "FAIL: $SVC missing. Render the skeleton first."
  exit 1
fi

check_no_placeholders() {
  local name="No unresolved \${{ values.* }}"
  if grep -r -q '\${{ *values\.' "$SVC"; then
    report+="$name: FAIL — hay placeholders sin resolver\n"
    failed=$((failed+1))
  else
    report+="$name: OK\n"; passed=$((passed+1))
  fi
}

check_catalog_fields() {
  local name="catalog-info.yaml has correct name/owner/tier"
  local ok
  ok="$(python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
ok = (d.get('metadata',{}).get('name') == 'svc-reports'
      and d.get('spec',{}).get('owner') == 'team-capstone'
      and d.get('spec',{}).get('tier') == 'tier-2')
print('yes' if ok else 'no')
" "$SVC/catalog-info.yaml" 2>/dev/null || echo no)"
  if [ "$ok" = "yes" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

check_main_py() {
  local name="app/main.py references svc-reports"
  if [ -f "$SVC/app/main.py" ] && grep -q "svc-reports" "$SVC/app/main.py"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

check_no_placeholders
check_catalog_fields
check_main_py

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
