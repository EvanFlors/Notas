#!/usr/bin/env bash
# Validate cap-01-03-precommit-debug.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `grep -q` on a pipe, which may trigger SIGPIPE upstream when grep exits
# early. pipefail would misreport those as failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-01-03}}"
passed=0
failed=0
report=""

check_done_marker() {
  local name="DONE marker"
  if [ -f "$BASE/DONE" ] && grep -qx "precommit-ok" "$BASE/DONE"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected '$BASE/DONE' with 'precommit-ok'\n"
    failed=$((failed+1))
  fi
}

check_yaml_no_tabs() {
  local name="broken-config.yaml has no tabs"
  local f="$BASE/broken-config.yaml"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL — '$f' missing\n"; failed=$((failed+1)); return
  fi
  if LC_ALL=C grep -q "$(printf '\t')" "$f" 2>/dev/null; then
    report+="$name: FAIL — tabs still present\n"; failed=$((failed+1))
  else
    report+="$name: OK\n"; passed=$((passed+1))
  fi
}

check_py_no_unused_os() {
  local name="bad_code.py has no 'import os' leftover"
  local f="$BASE/bad_code.py"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL — '$f' missing\n"; failed=$((failed+1)); return
  fi
  if grep -qE '^import os' "$f"; then
    report+="$name: FAIL — 'import os' still present\n"; failed=$((failed+1))
  else
    report+="$name: OK\n"; passed=$((passed+1))
  fi
}

check_py_has_type_hints() {
  local name="bad_code.py has return type annotation"
  local f="$BASE/bad_code.py"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL — '$f' missing\n"; failed=$((failed+1)); return
  fi
  if grep -qE -- '-> *int' "$f"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected '-> int' annotation on add()\n"
    failed=$((failed+1))
  fi
}

check_no_trailing_ws() {
  local name="trailing.txt has no trailing whitespace"
  local f="$BASE/trailing.txt"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL — '$f' missing\n"; failed=$((failed+1)); return
  fi
  if grep -qE ' +$' "$f"; then
    report+="$name: FAIL — trailing whitespace still present\n"
    failed=$((failed+1))
  else
    report+="$name: OK\n"; passed=$((passed+1))
  fi
}

echo "== Validating cap-01-03-precommit-debug under $BASE =="
if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Follow README.md first."
  exit 1
fi

check_done_marker
check_yaml_no_tabs
check_py_no_unused_os
check_py_has_type_hints
check_no_trailing_ws

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/5 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
