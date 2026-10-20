#!/usr/bin/env bash
# Validate cap-01-01-bootstrap-app.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `cmd | grep -q ...` that may trigger SIGPIPE on the left-hand side when
# grep exits early. pipefail would turn those into spurious failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-01-01}}"
passed=0
failed=0
report=""

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available"
  exit 0
fi
if ! python3 -c "import sqlite3" >/dev/null 2>&1; then
  echo "SKIP: sqlite3 stdlib module not available"
  exit 0
fi

check_done_file() {
  local name="DONE marker"
  if [ -f "$BASE/DONE" ] && grep -qx "bootstrap-ok" "$BASE/DONE"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected '$BASE/DONE' with 'bootstrap-ok'\n"
    failed=$((failed+1))
  fi
}

check_sqlite_has_task() {
  local name="SQLite tasks row"
  local db="$BASE/app/app.db"
  if [ ! -f "$db" ]; then
    report+="$name: FAIL — '$db' missing\n"; failed=$((failed+1)); return
  fi
  local count
  count="$(python3 -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); print(c.execute('select count(*) from tasks').fetchone()[0])" "$db" 2>/dev/null || echo "")"
  if [ "${count:-0}" -ge 1 ] 2>/dev/null; then
    report+="$name: OK ($count rows)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — tasks table empty or missing\n"
    failed=$((failed+1))
  fi
}

echo "== Validating cap-01-01-bootstrap-app under $BASE =="
if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Follow README.md first."
  exit 1
fi

check_done_file
check_sqlite_has_task

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/2 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
