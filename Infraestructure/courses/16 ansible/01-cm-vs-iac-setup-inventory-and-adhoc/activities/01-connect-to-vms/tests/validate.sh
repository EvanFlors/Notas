#!/usr/bin/env bash
# Structural + light-runtime validation for ans-01-01-connect-to-vms.
#
# Checks that the student produced the five expected artifacts under
# $BASE, that inventory.yml declares a 'managed' group, that
# inventory-list.json includes 'managed' with hosts, and that the
# ad-hoc outputs show evidence of a successful ping (pong) and uptime
# (load average).
#
# If ansible is not installed we SKIP the live re-run and only validate
# the artifacts that the student already captured. If both ansible is
# missing AND the artifacts are missing, we SKIP (exit 0) and tell the
# student which tool they need.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/ans-01-01}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "SKIP: $BASE does not exist. Create it per the activity README (mkdir -p $BASE)."
  exit 0
fi

have_ansible=0
if command -v ansible >/dev/null 2>&1 && command -v ansible-inventory >/dev/null 2>&1; then
  have_ansible=1
fi

if [ "$have_ansible" -eq 0 ]; then
  echo "SKIP-note: 'ansible' not found. Will validate captured artifacts only."
  echo "           Install with: pipx install --include-deps ansible"
fi

INV="$BASE/inventory.yml"
LIST="$BASE/inventory-list.json"
GRAPH="$BASE/inventory-graph.txt"
PING="$BASE/ping-output.txt"
ADHOC="$BASE/adhoc-output.txt"

for f in "$INV" "$LIST" "$GRAPH" "$PING" "$ADHOC"; do
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
  else
    echo "  FAIL $(basename "$f") missing (expected at $f)"
    fail=$((fail+1))
  fi
done

# inventory.yml must mention 'managed' group and either 'hosts' or 'children'.
if [ -f "$INV" ]; then
  if grep -qE '^\s*managed\s*:' "$INV"; then
    echo "  OK   inventory.yml declares a 'managed' group"
  else
    echo "  FAIL inventory.yml does not declare a 'managed' group"
    fail=$((fail+1))
  fi
  if grep -qE '^\s*(hosts|children)\s*:' "$INV"; then
    echo "  OK   inventory.yml uses hosts/children keys"
  else
    echo "  FAIL inventory.yml missing hosts/children keys"
    fail=$((fail+1))
  fi
fi

# inventory-list.json must be valid JSON (if python3 available) and mention 'managed'.
if [ -f "$LIST" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$LIST" >/dev/null 2>&1; then
      echo "  OK   inventory-list.json is valid JSON"
    else
      echo "  FAIL inventory-list.json is not valid JSON"
      fail=$((fail+1))
    fi
  fi
  if grep -q '"managed"' "$LIST"; then
    echo "  OK   inventory-list.json includes 'managed'"
  else
    echo "  FAIL inventory-list.json does not reference 'managed'"
    fail=$((fail+1))
  fi
fi

# inventory-graph.txt must mention @managed
if [ -f "$GRAPH" ]; then
  if grep -q '@managed' "$GRAPH"; then
    echo "  OK   inventory-graph.txt shows @managed"
  else
    echo "  FAIL inventory-graph.txt does not show @managed"
    fail=$((fail+1))
  fi
fi

# ping-output.txt must contain 'pong' and must NOT contain 'UNREACHABLE'
if [ -f "$PING" ]; then
  if grep -q 'pong' "$PING"; then
    echo "  OK   ping-output.txt contains 'pong'"
  else
    echo "  FAIL ping-output.txt does not contain 'pong'"
    fail=$((fail+1))
  fi
  if grep -q 'UNREACHABLE' "$PING"; then
    echo "  FAIL ping-output.txt reports UNREACHABLE host(s)"
    fail=$((fail+1))
  else
    echo "  OK   ping-output.txt has no UNREACHABLE entries"
  fi
fi

# adhoc-output.txt must contain 'load average' (uptime typical output)
if [ -f "$ADHOC" ]; then
  if grep -q 'load average' "$ADHOC"; then
    echo "  OK   adhoc-output.txt contains 'load average' (uptime)"
  else
    echo "  FAIL adhoc-output.txt does not contain 'load average'"
    fail=$((fail+1))
  fi
fi

# If ansible is available AND inventory exists, do a quick live re-check.
if [ "$have_ansible" -eq 1 ] && [ -f "$INV" ]; then
  echo "-- live re-check with ansible-inventory --"
  if ansible-inventory -i "$INV" --list >/dev/null 2>&1; then
    echo "  OK   ansible-inventory parses inventory.yml"
  else
    echo "  FAIL ansible-inventory failed to parse inventory.yml"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
