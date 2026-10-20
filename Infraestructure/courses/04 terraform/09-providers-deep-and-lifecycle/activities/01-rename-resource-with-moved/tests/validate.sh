#!/usr/bin/env bash
# Validate tf-09-01-rename-resource-with-moved.
#
# Note: deliberately do NOT enable `set -o pipefail` — many checks pipe into
# `grep -q`, which closes early and causes SIGPIPE (exit 141) on the producer.
# pipefail would spuriously mark those as failures.

BASE="${1:-${BASE_DIR:-/tmp/tf-09-01}}"
passed=0
failed=0
report=""

# Pick terraform or tofu, whichever is available.
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

# Version check (TF >= 1.5 or OpenTofu >= 1.6).
tf_version="$("$TF" version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
if [ -z "$tf_version" ]; then
  report+="PRE: FAIL (could not detect $TF version)\n"
  failed=$((failed+1))
else
  report+="PRE: $TF $tf_version\n"
fi

check_1_dir() {
  local name="1. working dir exists"
  if [ -d "$BASE" ] && [ -f "$BASE/main.tf" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL ($BASE/main.tf missing)\n"; failed=$((failed+1))
  fi
}

check_2_state_only_new_name() {
  local name="2. state has only local_file.new_name"
  if [ ! -d "$BASE/.terraform" ]; then
    report+="$name: FAIL (no .terraform/, run 'terraform init' + 'apply')\n"
    failed=$((failed+1)); return
  fi
  cd "$BASE" || { report+="$name: FAIL (cd)\n"; failed=$((failed+1)); return; }
  local state_list
  state_list="$("$TF" state list 2>/dev/null)"
  if echo "$state_list" | grep -q '^local_file.new_name$' \
     && ! echo "$state_list" | grep -q '^local_file.old_name$'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (state list = $state_list)\n"; failed=$((failed+1))
  fi
}

check_3_moved_block() {
  local name="3. main.tf has moved block old_name -> new_name"
  local f="$BASE/main.tf"
  # Collapse whitespace to tolerate formatting variants.
  local collapsed
  collapsed="$(tr -s '[:space:]' ' ' < "$f")"
  if echo "$collapsed" | grep -q 'moved {' \
     && echo "$collapsed" | grep -q 'from = local_file.old_name' \
     && echo "$collapsed" | grep -q 'to = local_file.new_name'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (missing or malformed moved block in main.tf)\n"
    failed=$((failed+1))
  fi
}

check_4_plan_clean() {
  local name="4. terraform plan is clean (exit 0 with -detailed-exitcode)"
  cd "$BASE" || { report+="$name: FAIL (cd)\n"; failed=$((failed+1)); return; }
  "$TF" plan -detailed-exitcode -input=false >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (exit=$rc; expected 0, got 2 = pending changes)\n"
    failed=$((failed+1))
  fi
}

check_5_file_contents() {
  local name="5. /tmp/tf-09-01/greeting.txt exists with expected content"
  if [ -f "$BASE/greeting.txt" ] && grep -q 'hola desde tf-09-01' "$BASE/greeting.txt"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (file missing or wrong content)\n"; failed=$((failed+1))
  fi
}

check_1_dir
check_2_state_only_new_name
check_3_moved_block
check_4_plan_clean
check_5_file_contents

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
