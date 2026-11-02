#!/usr/bin/env bash
# Validate: student fixed broken.sh per sys-13-02-quoting-dojo.
# Usage: bash validate.sh [path-to-fixed.sh]
# Defaults to /tmp/fixed.sh.

set -o pipefail

SCRIPT="${1:-/tmp/fixed.sh}"
fail=0

echo "== Validating fixed.sh at: $SCRIPT =="

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: file does not exist: $SCRIPT"
  exit 1
fi

# Shebang + strict mode + executable
first_line="$(head -n 1 "$SCRIPT")"
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  echo "  OK   shebang"
else
  echo "  FAIL shebang: '$first_line'"
  fail=$((fail+1))
fi

if grep -qE '^[[:space:]]*set[[:space:]]+-euo[[:space:]]+pipefail' "$SCRIPT"; then
  echo "  OK   set -euo pipefail"
else
  echo "  FAIL set -euo pipefail missing"
  fail=$((fail+1))
fi

if [ -x "$SCRIPT" ]; then
  echo "  OK   executable"
else
  echo "  FAIL not executable"
  fail=$((fail+1))
fi

# Build hostile sandbox
TMP="$(mktemp -d)"
SRC="$TMP/mi carpeta"
DST="$TMP/dst"
mkdir -p "$SRC" "$DST"

touch "$SRC/normal.log"
touch "$SRC/con espacio.log"
touch "$SRC/no-matching.txt"

nl_name=$'bad\nname.log'
touch "$SRC/$nl_name"

# Behavior test: pattern '*.log' must match the 3 .log files
set +e
out="$("$SCRIPT" "$SRC" "$DST" '*.log' 2>&1)"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "  FAIL script exited $rc on happy path. Output:"
  echo "$out" | sed 's/^/     /'
  fail=$((fail+1))
else
  echo "  OK   runs on hostile fixtures (exit 0)"
fi

# Count .log files in dst (expect 3). Use -print0 so filenames with
# newlines count as one file, not two.
copied="$(find "$DST" -type f -name "*.log" -print0 | tr -cd '\0' | wc -c | tr -d ' ')"
if [ "$copied" = "3" ]; then
  echo "  OK   3 .log files copied (space + newline + normal)"
else
  echo "  FAIL expected 3 .log files in dst, got $copied"
  find "$DST" -type f | sed 's/^/     /'
  fail=$((fail+1))
fi

# .txt must NOT be copied
if find "$DST" -type f -name "*.txt" | grep -q .; then
  echo "  FAIL .txt file was copied (pattern leaked)"
  fail=$((fail+1))
else
  echo "  OK   .txt files were not copied"
fi

# Missing args must abort
set +e
"$SCRIPT" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "  OK   missing args aborts (exit $rc)"
else
  echo "  FAIL missing args should abort"
  fail=$((fail+1))
fi

# Pattern must be preserved literally (not expanded in CWD)
# Trick: run from a dir with a .log file; pattern should still only match SRC.
pushd "$TMP" >/dev/null
touch "cwd-side.log"
rm -rf "$DST" && mkdir "$DST"
set +e
"$SCRIPT" "$SRC" "$DST" '*.log' >/dev/null 2>&1
set -e
if find "$DST" -name "cwd-side.log" | grep -q .; then
  echo "  FAIL pattern expanded in CWD (cwd-side.log leaked into dst)"
  fail=$((fail+1))
else
  echo "  OK   pattern not expanded in CWD"
fi
popd >/dev/null

# shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT" >/dev/null 2>&1; then
    echo "  OK   shellcheck clean"
  else
    echo "  FAIL shellcheck warnings:"
    shellcheck "$SCRIPT" || true
    fail=$((fail+1))
  fi
else
  echo "  SKIP shellcheck not installed"
fi

# Reject taping over warnings
if grep -qE '# *shellcheck +disable=' "$SCRIPT"; then
  echo "  FAIL 'shellcheck disable=' pragma found — fix the issue instead"
  fail=$((fail+1))
else
  echo "  OK   no shellcheck disable pragmas"
fi

# Cleanup
rm -rf "$TMP"

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
