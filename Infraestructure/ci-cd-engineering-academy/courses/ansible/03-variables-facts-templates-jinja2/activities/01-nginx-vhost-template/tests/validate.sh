#!/usr/bin/env bash
# Structural + behavioural validation for
# ans-03-01-nginx-vhost-template.
#
# Checks that the student produced inventory.ini, playbook.yml and
# templates/vhost.conf.j2 in BASE, runs the playbook with
# ansible-playbook, and inspects the rendered output/vhost.conf.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# If ansible-playbook is not installed on this machine, the test exits
# with SKIP (code 0) and a clear message. The student still has to run
# the playbook themselves to actually complete the exercise.

set -eu

BASE="${1:-/tmp/ans-03-vhost}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "SKIP: ansible-playbook is not installed."
  echo "      Install ansible-core (e.g. 'pipx install ansible') and re-run."
  exit 0
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

INV="$BASE/inventory.ini"
PLAY="$BASE/playbook.yml"
TPL="$BASE/templates/vhost.conf.j2"

check_file_exists "$INV" || true
check_file_exists "$PLAY" || true
check_file_exists "$TPL"  || true

# Template must use a for loop (not hardcoded upstream list).
if [ -f "$TPL" ]; then
  if grep -qE '\{%-?\s*for\s+' "$TPL"; then
    echo "  OK   template uses a {% for %} loop"
  else
    echo "  FAIL template does not use a {% for %} loop (upstreams should be iterated)"
    fail=$((fail+1))
  fi
  if grep -q 'ansible_managed' "$TPL"; then
    echo "  OK   template contains the ansible_managed marker"
  else
    echo "  FAIL template is missing the {{ ansible_managed }} marker"
    fail=$((fail+1))
  fi
  if grep -qE 'server_name\s+\{\{\s*vhost_server_name' "$TPL"; then
    echo "  OK   template uses {{ vhost_server_name }} on server_name"
  else
    echo "  FAIL template does not use {{ vhost_server_name }} on server_name"
    fail=$((fail+1))
  fi
  if grep -qE 'listen\s+\{\{\s*vhost_listen_port' "$TPL"; then
    echo "  OK   template uses {{ vhost_listen_port }} on listen"
  else
    echo "  FAIL template does not use {{ vhost_listen_port }} on listen"
    fail=$((fail+1))
  fi
fi

# Playbook must declare the three required vars.
if [ -f "$PLAY" ]; then
  for v in "vhost_server_name" "vhost_listen_port" "vhost_upstreams"; do
    if grep -q "$v" "$PLAY"; then
      echo "  OK   playbook declares $v"
    else
      echo "  FAIL playbook does not declare $v"
      fail=$((fail+1))
    fi
  done
fi

# Early exit if any file is missing — can't run the playbook.
if [ ! -f "$INV" ] || [ ! -f "$PLAY" ] || [ ! -f "$TPL" ]; then
  echo
  echo "RESULT: required files missing; skipping playbook execution."
  exit 1
fi

# Run the playbook and inspect the rendered output.
echo
echo "== Running ansible-playbook =="
if ! (cd "$BASE" && ansible-playbook -i inventory.ini playbook.yml >/tmp/ans-03-vhost-run.log 2>&1); then
  echo "  FAIL ansible-playbook execution failed. See /tmp/ans-03-vhost-run.log"
  tail -20 /tmp/ans-03-vhost-run.log || true
  exit 1
fi
echo "  OK   ansible-playbook ran without error"

RENDERED="$BASE/output/vhost.conf"
if [ ! -f "$RENDERED" ]; then
  echo "  FAIL $RENDERED was not produced by the playbook"
  exit 1
fi
echo "  OK   $RENDERED exists"

if grep -qE '^\s*server_name\s+\S+;' "$RENDERED"; then
  echo "  OK   rendered file has a server_name directive"
else
  echo "  FAIL rendered file has no server_name directive"
  fail=$((fail+1))
fi

if grep -qE '^\s*listen\s+[0-9]+;' "$RENDERED"; then
  echo "  OK   rendered file has a listen <port>; directive"
else
  echo "  FAIL rendered file has no listen <port>; directive"
  fail=$((fail+1))
fi

# Count `server <ip>:<port>;` lines inside the upstream block.
upstream_count=$(grep -cE '^\s*server\s+[0-9A-Za-z._-]+:[0-9]+;' "$RENDERED" || true)
if [ "$upstream_count" -ge 2 ]; then
  echo "  OK   rendered file has >= 2 upstream server lines (${upstream_count} found)"
else
  echo "  FAIL rendered file has only ${upstream_count} upstream server lines (expected >= 2)"
  fail=$((fail+1))
fi

if grep -q 'proxy_pass http://backend' "$RENDERED"; then
  echo "  OK   rendered file proxies to the backend upstream"
else
  echo "  FAIL rendered file does not proxy to http://backend"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: vhost template renders correctly from the playbook."
exit 0
