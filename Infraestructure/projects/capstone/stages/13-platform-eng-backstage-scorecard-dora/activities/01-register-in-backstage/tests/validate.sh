#!/usr/bin/env bash
# Validate cap-13-01-register-in-backstage.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `cmd | grep -q ...` that may trigger SIGPIPE on the left-hand side when
# grep exits early. pipefail would turn those into spurious failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-13-01}}"
FILE="$BASE/catalog-info.yaml"
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

echo "== Validating cap-13-01-register-in-backstage under $BASE =="
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing. Follow README.md."
  exit 1
fi

check_four_docs() {
  local name="4 YAML documents"
  local count
  count="$(python3 -c "
import sys, yaml
docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if isinstance(d, dict)]
print(len(docs))
" "$FILE" 2>/dev/null || echo 0)"
  if [ "${count:-0}" -eq 4 ]; then
    report+="$name: OK (${count})\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected 4 docs, got ${count}\n"
    failed=$((failed+1))
  fi
}

check_four_kinds() {
  local name="Component + API + Resource + System present"
  local ok
  ok="$(python3 -c "
import sys, yaml
docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if isinstance(d, dict)]
kinds = {d.get('kind') for d in docs}
need = {'Component', 'API', 'Resource', 'System'}
print('yes' if need.issubset(kinds) else 'no')
" "$FILE" 2>/dev/null || echo no)"
  if [ "$ok" = "yes" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — some kind missing\n"
    failed=$((failed+1))
  fi
}

check_scorecard_annotations() {
  local name="Component has 7 scorecard annotations"
  local ok
  ok="$(python3 -c "
import sys, yaml
docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if isinstance(d, dict)]
comp = next((d for d in docs if d.get('kind') == 'Component'), None)
need = {'slo_url','runbook_url','oncall_rotation','image_signed','cves_critical','last_deploy_days','k8s_psa'}
ann = (comp or {}).get('metadata', {}).get('annotations') or {}
have = {k for k, v in ann.items() if v not in (None, '')}
print('yes' if need.issubset(have) else 'no')
" "$FILE" 2>/dev/null || echo no)"
  if [ "$ok" = "yes" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — faltan anotaciones en el Component\n"
    failed=$((failed+1))
  fi
}

check_four_docs
check_four_kinds
check_scorecard_annotations

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
