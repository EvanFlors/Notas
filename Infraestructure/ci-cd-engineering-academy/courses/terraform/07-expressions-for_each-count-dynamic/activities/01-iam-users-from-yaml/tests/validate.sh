#!/usr/bin/env bash
# Validate tf-07-01-iam-users-from-yaml.
# Checks: 4 generated files exist with correct content, and main.tf uses
# yamldecode + for_each (not count).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `grep -q` on command output; with pipefail a successful early-match grep
# that closes the pipe can mark the pipeline as failed (SIGPIPE / exit 141).

BASE="${1:-${BASE_DIR:-/tmp/tf-07-01}}"
passed=0
failed=0
report=""

check_file_exists() {
  local path="$1" name="$2"
  if [ -f "$path" ]; then
    report+="$name: OK (exists)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (missing $path)\n"; failed=$((failed+1))
  fi
}

check_file_contains() {
  local path="$1" needle="$2" name="$3"
  if [ ! -f "$path" ]; then
    report+="$name: FAIL (file $path missing)\n"; failed=$((failed+1)); return
  fi
  if grep -q -- "$needle" "$path"; then
    report+="$name: OK (contains '$needle')\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (does not contain '$needle' in $path)\n"; failed=$((failed+1))
  fi
}

echo "== Validating tf-07-01-iam-users-from-yaml =="
echo "BASE=$BASE"
echo

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE does not exist. Did you copy starter/ there and run 'terraform apply'?"
  exit 2
fi

# 1. Four output files exist.
for user in alice bob carol dave; do
  check_file_exists "$BASE/out/${user}.txt" "file[${user}.txt]"
done

# 2. Each file contains the expected name and email.
check_file_contains "$BASE/out/alice.txt" "name=Alice Rivera"  "content[alice.name]"
check_file_contains "$BASE/out/alice.txt" "email=alice@acme.io" "content[alice.email]"
check_file_contains "$BASE/out/bob.txt"   "name=Bob Chen"       "content[bob.name]"
check_file_contains "$BASE/out/bob.txt"   "email=bob@acme.io"   "content[bob.email]"
check_file_contains "$BASE/out/carol.txt" "name=Carol Diaz"     "content[carol.name]"
check_file_contains "$BASE/out/carol.txt" "email=carol@acme.io" "content[carol.email]"
check_file_contains "$BASE/out/dave.txt"  "name=Dave Patel"     "content[dave.name]"
check_file_contains "$BASE/out/dave.txt"  "email=dave@acme.io"  "content[dave.email]"

# 3. main.tf uses yamldecode and for_each; must NOT use count.
MAIN="$BASE/main.tf"
if [ ! -f "$MAIN" ]; then
  report+="hcl[main.tf]: FAIL (missing)\n"; failed=$((failed+1))
else
  if grep -q "yamldecode" "$MAIN"; then
    report+="hcl[yamldecode]: OK\n"; passed=$((passed+1))
  else
    report+="hcl[yamldecode]: FAIL (main.tf debe usar yamldecode)\n"; failed=$((failed+1))
  fi
  if grep -q "for_each" "$MAIN"; then
    report+="hcl[for_each]: OK\n"; passed=$((passed+1))
  else
    report+="hcl[for_each]: FAIL (main.tf debe usar for_each)\n"; failed=$((failed+1))
  fi
  if grep -qE "^[^#]*\bcount\s*=" "$MAIN"; then
    report+="hcl[no-count]: FAIL (main.tf no debe usar count para esto)\n"; failed=$((failed+1))
  else
    report+="hcl[no-count]: OK\n"; passed=$((passed+1))
  fi
fi

echo
printf "%b" "$report"
echo
echo "== Summary =="
echo "PASS: $passed"
echo "FAIL: $failed"

[ "$failed" -eq 0 ] || exit 1
exit 0
