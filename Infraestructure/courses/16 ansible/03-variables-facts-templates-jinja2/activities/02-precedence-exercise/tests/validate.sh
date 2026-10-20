#!/usr/bin/env bash
# Structural + behavioural validation for
# ans-03-02-precedence-exercise.
#
# Checks that the student built the inventory + group_vars + host_vars +
# playbook + template layout, runs the playbook twice (once with the
# in-play 'vars:' winning, once overriding with -e app_port=9999) and
# verifies that output/precedence-report.txt reflects the correct
# precedence.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# If ansible-playbook is not installed, this test exits with SKIP (0).

set -eu

BASE="${1:-/tmp/ans-03-prec}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "SKIP: ansible-playbook is not installed."
  echo "      Install ansible-core (e.g. 'pipx install ansible') and re-run."
  exit 0
fi

check_exists() {
  local f="$1"
  if [ -e "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

INV="$BASE/inventory.yml"
PLAY="$BASE/playbook.yml"
GV_ALL="$BASE/group_vars/all.yml"
GV_WEB="$BASE/group_vars/web.yml"
HV_WEB2="$BASE/host_vars/web2.yml"
TPL="$BASE/templates/precedence-report.txt.j2"

check_exists "$INV"     || true
check_exists "$PLAY"    || true
check_exists "$GV_ALL"  || true
check_exists "$GV_WEB"  || true
check_exists "$HV_WEB2" || true
check_exists "$TPL"     || true

# Inventory must declare the three expected hosts and the two groups.
if [ -f "$INV" ]; then
  for h in web1 web2 db1; do
    if grep -q "$h" "$INV"; then
      echo "  OK   inventory mentions host $h"
    else
      echo "  FAIL inventory does not mention host $h"
      fail=$((fail+1))
    fi
  done
  for g in web db; do
    if grep -qE "^[[:space:]]*${g}:" "$INV"; then
      echo "  OK   inventory declares group $g"
    else
      echo "  FAIL inventory does not declare group $g"
      fail=$((fail+1))
    fi
  done
fi

# Group/host vars sanity.
if [ -f "$GV_ALL" ] && ! grep -qE 'app_port:\s*[0-9]+' "$GV_ALL"; then
  echo "  FAIL $GV_ALL does not set app_port"
  fail=$((fail+1))
fi
if [ -f "$GV_WEB" ] && ! grep -qE 'app_port:\s*[0-9]+' "$GV_WEB"; then
  echo "  FAIL $GV_WEB does not set app_port"
  fail=$((fail+1))
fi
if [ -f "$HV_WEB2" ] && ! grep -qE 'app_port:\s*[0-9]+' "$HV_WEB2"; then
  echo "  FAIL $HV_WEB2 does not set app_port"
  fail=$((fail+1))
fi

# Playbook must declare 'vars:' with app_port and use run_once + delegate_to.
if [ -f "$PLAY" ]; then
  if grep -qE 'app_port:\s*[0-9]+' "$PLAY"; then
    echo "  OK   playbook declares a vars-level app_port"
  else
    echo "  FAIL playbook does not declare a vars-level app_port"
    fail=$((fail+1))
  fi
  if grep -q 'run_once' "$PLAY"; then
    echo "  OK   playbook uses run_once"
  else
    echo "  FAIL playbook does not use run_once (template would run per host)"
    fail=$((fail+1))
  fi
  if grep -q 'delegate_to' "$PLAY"; then
    echo "  OK   playbook uses delegate_to"
  else
    echo "  FAIL playbook does not use delegate_to"
    fail=$((fail+1))
  fi
fi

# Template must iterate groups['all'] and read hostvars[h].app_port.
if [ -f "$TPL" ]; then
  if grep -qE "groups\\[['\"]all['\"]\\]" "$TPL"; then
    echo "  OK   template iterates groups['all']"
  else
    echo "  FAIL template does not iterate groups['all']"
    fail=$((fail+1))
  fi
  if grep -q 'hostvars' "$TPL"; then
    echo "  OK   template reads hostvars"
  else
    echo "  FAIL template does not read hostvars"
    fail=$((fail+1))
  fi
fi

# Can't proceed if essentials missing.
if [ ! -f "$INV" ] || [ ! -f "$PLAY" ] || [ ! -f "$TPL" ]; then
  echo
  echo "RESULT: required files missing; skipping playbook execution."
  exit 1
fi

echo
echo "== Running ansible-playbook (default run) =="
if ! (cd "$BASE" && ansible-playbook -i inventory.yml playbook.yml >/tmp/ans-03-prec-run1.log 2>&1); then
  echo "  FAIL ansible-playbook failed. See /tmp/ans-03-prec-run1.log"
  tail -20 /tmp/ans-03-prec-run1.log || true
  exit 1
fi
echo "  OK   first ansible-playbook run succeeded"

REP="$BASE/output/precedence-report.txt"
if [ ! -f "$REP" ]; then
  echo "  FAIL $REP was not produced"
  exit 1
fi
echo "  OK   $REP produced"

# Must have one line per host matching '<host>: app_port=<n>'.
for h in web1 web2 db1; do
  if grep -qE "^${h}: app_port=[0-9]+" "$REP"; then
    echo "  OK   report has a line for $h"
  else
    echo "  FAIL report has no 'app_port=' line for $h"
    fail=$((fail+1))
  fi
done

# The 3 values should all equal the play-vars value (the point of the
# exercise: play vars > inventory host_vars/group_vars).
distinct=$(grep -oE 'app_port=[0-9]+' "$REP" | sort -u | wc -l | tr -d ' ')
if [ "$distinct" = "1" ]; then
  echo "  OK   all three hosts share the same app_port (play vars won)"
else
  echo "  FAIL hosts have ${distinct} distinct app_port values (expected 1 — play vars should flatten them)"
  fail=$((fail+1))
fi

echo
echo "== Running ansible-playbook with -e app_port=9999 =="
if ! (cd "$BASE" && ansible-playbook -i inventory.yml playbook.yml -e app_port=9999 >/tmp/ans-03-prec-run2.log 2>&1); then
  echo "  FAIL ansible-playbook with extra vars failed. See /tmp/ans-03-prec-run2.log"
  tail -20 /tmp/ans-03-prec-run2.log || true
  exit 1
fi
echo "  OK   second run (with -e) succeeded"

nine_count=$(grep -cE "app_port=9999" "$REP" || true)
if [ "$nine_count" -ge 3 ]; then
  echo "  OK   report shows app_port=9999 for all three hosts (extra vars won)"
else
  echo "  FAIL report shows app_port=9999 only ${nine_count} times (expected >= 3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: precedence exercise behaves as expected."
exit 0
