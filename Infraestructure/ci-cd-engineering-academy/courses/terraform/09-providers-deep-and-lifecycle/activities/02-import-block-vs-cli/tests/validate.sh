#!/usr/bin/env bash
# Validate tf-09-02-import-block-vs-cli.
#
# Note: deliberately do NOT enable `set -o pipefail` — many checks pipe into
# `grep -q`, which closes early and causes SIGPIPE (exit 141) on the producer.
# pipefail would spuriously mark those as failures.

BASE="${1:-${BASE_DIR:-/tmp/tf-09-02}}"
passed=0
failed=0
report=""

TF=""
if command -v terraform >/dev/null 2>&1; then
  TF="terraform"
elif command -v tofu >/dev/null 2>&1; then
  TF="tofu"
else
  echo "FAIL: neither 'terraform' nor 'tofu' found in PATH" >&2
  echo "RESULT: FAIL"
  exit 1
fi

tf_version="$("$TF" version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
if [ -z "$tf_version" ]; then
  report+="PRE: FAIL (could not detect $TF version)\n"
  failed=$((failed+1))
else
  report+="PRE: $TF $tf_version\n"
fi

check_1_dir() {
  local name="1. working dir + main.tf"
  if [ -d "$BASE" ] && [ -f "$BASE/main.tf" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL ($BASE/main.tf missing)\n"; failed=$((failed+1))
  fi
}

check_2_import_block() {
  local name="2. main.tf has import block for random_id.adopted id=AAAAAA"
  local f="$BASE/main.tf"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL (no main.tf)\n"; failed=$((failed+1)); return
  fi
  local collapsed
  collapsed="$(tr -s '[:space:]' ' ' < "$f")"
  if echo "$collapsed" | grep -q 'import {' \
     && echo "$collapsed" | grep -q 'to = random_id.adopted' \
     && echo "$collapsed" | grep -q 'id = "AAAAAA"'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (missing or malformed import block)\n"; failed=$((failed+1))
  fi
}

check_3_resource_block() {
  local name="3. main.tf declares resource random_id.adopted"
  local f="$BASE/main.tf"
  local collapsed
  collapsed="$(tr -s '[:space:]' ' ' < "$f")"
  if echo "$collapsed" | grep -q 'resource "random_id" "adopted"'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (resource random_id.adopted not declared)\n"
    failed=$((failed+1))
  fi
}

check_4_state_has_adopted() {
  local name="4. terraform state list contains random_id.adopted"
  if [ ! -d "$BASE/.terraform" ]; then
    report+="$name: FAIL (no .terraform/, did you run init+apply?)\n"
    failed=$((failed+1)); return
  fi
  cd "$BASE" || { report+="$name: FAIL (cd)\n"; failed=$((failed+1)); return; }
  local state_list
  state_list="$("$TF" state list 2>/dev/null)"
  if echo "$state_list" | grep -q '^random_id.adopted$'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (state_list=$state_list)\n"; failed=$((failed+1))
  fi
}

check_5_plan_clean() {
  local name="5. terraform plan is clean (exit 0)"
  cd "$BASE" || { report+="$name: FAIL (cd)\n"; failed=$((failed+1)); return; }
  "$TF" plan -detailed-exitcode -input=false >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (plan exit=$rc; expected 0, got 2 = pending changes)\n"
    failed=$((failed+1))
  fi
}

check_1_dir
check_2_import_block
check_3_resource_block
check_4_state_has_adopted
check_5_plan_clean

printf "%b" "$report"
echo "---"
echo "passed=$passed failed=$failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
