#!/usr/bin/env bash
# Validate: student built greet.sh per sys-13-01-first-parameterized-script.
# Usage: bash validate.sh [path-to-greet.sh]
# Defaults to /tmp/greet.sh.

set -o pipefail

SCRIPT="${1:-/tmp/greet.sh}"
fail=0

echo "== Validating greet.sh at: $SCRIPT =="

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: file does not exist: $SCRIPT"
  exit 1
fi

# Shebang
first_line="$(head -n 1 "$SCRIPT")"
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  echo "  OK   shebang: #!/usr/bin/env bash"
else
  echo "  FAIL shebang incorrect: '$first_line' (expected '#!/usr/bin/env bash')"
  fail=$((fail+1))
fi

# Strict mode
if grep -qE '^[[:space:]]*set[[:space:]]+-euo[[:space:]]+pipefail' "$SCRIPT"; then
  echo "  OK   set -euo pipefail present"
else
  echo "  FAIL 'set -euo pipefail' not found"
  fail=$((fail+1))
fi

# Executable bit
if [ -x "$SCRIPT" ]; then
  echo "  OK   executable bit set"
else
  echo "  FAIL script is not executable (chmod +x)"
  fail=$((fail+1))
fi

# Behavior 1: with full args
out="$("$SCRIPT" Ana Hola "Equipo SRE" 2>/dev/null || true)"
if echo "$out" | grep -q "Hola Ana" && echo "$out" | grep -q "Equipo SRE"; then
  echo "  OK   full-args output contains greeting + signature"
else
  echo "  FAIL full-args output unexpected: $out"
  fail=$((fail+1))
fi

# Behavior 2: name with spaces
out="$("$SCRIPT" "Ana Luz" Hola firma 2>/dev/null || true)"
if echo "$out" | grep -q "Hola Ana Luz"; then
  echo "  OK   name with spaces preserved"
else
  echo "  FAIL name with spaces mangled: $out"
  fail=$((fail+1))
fi

# Behavior 3: missing signature must abort
set +e
"$SCRIPT" Ana Hola >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "  OK   missing signature aborts (exit $rc)"
else
  echo "  FAIL missing signature should abort, but exit was 0"
  fail=$((fail+1))
fi

# Behavior 4: default name applied when no args AND signature IS passed
out="$("$SCRIPT" "" "" firma 2>/dev/null || true)"
# empty args should fallback to defaults
if echo "$out" | grep -q "Hola mundo"; then
  echo "  OK   defaults applied when args empty"
else
  echo "  FAIL defaults not applied: $out"
  fail=$((fail+1))
fi

# shellcheck clean (if available)
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT" >/dev/null 2>&1; then
    echo "  OK   shellcheck clean"
  else
    echo "  FAIL shellcheck reported warnings:"
    shellcheck "$SCRIPT" || true
    fail=$((fail+1))
  fi
else
  echo "  SKIP shellcheck not installed"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
