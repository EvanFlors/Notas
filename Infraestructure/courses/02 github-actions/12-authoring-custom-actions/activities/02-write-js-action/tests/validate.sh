#!/usr/bin/env bash
# Validate gha-12-02-write-js-action.
#
# Checks:
#   1. action.yml structure (node20, main dist/index.js, 3 inputs, 3 outputs).
#   2. dist/index.js exists.
#   3. Running `node dist/index.js` with INPUT_PATH=./fixtures gives:
#        total-lines=18, file-count=3, top-file ends with 'c.py'
#   4. INPUT_PATTERN=**/*.py restricts to c.py (10 lines, 1 file).
#   5. INPUT_FAIL_THRESHOLD=5 → process exits non-zero.
#
# NOTE: no `set -o pipefail`; some pipes (long producers | grep -q) can SIGPIPE.

BASE="${1:-${BASE_DIR:-/tmp/js-action-lab}}"
ACTION="$BASE/line-counter"
passed=0; failed=0; report=""
note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating $ACTION =="

if [ ! -f "$ACTION/action.yml" ]; then
  echo "FAIL: $ACTION/action.yml not found. Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---------- Check 1: action.yml structure ----------
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required." >&2; exit 2
fi

struct="$(python3 - "$ACTION/action.yml" 2>&1 <<'PY'
import sys
try: import yaml
except ImportError:
    print("MISSING_YAML"); sys.exit(0)
try:
    d = yaml.safe_load(open(sys.argv[1]).read())
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)
errs = []
runs = d.get("runs") or {}
if runs.get("using") != "node20": errs.append(f"runs.using must be node20, got {runs.get('using')!r}")
if runs.get("main") != "dist/index.js": errs.append(f"runs.main must be dist/index.js, got {runs.get('main')!r}")
inp = d.get("inputs") or {}
for i in ("path","pattern","fail-threshold"):
    if i not in inp: errs.append(f"missing input: {i}")
out = d.get("outputs") or {}
for o in ("total-lines","file-count","top-file"):
    if o not in out: errs.append(f"missing output: {o}")
if "TODO" in (d.get("name","") or ""):  errs.append("name still TODO")
if "TODO" in (d.get("description","") or ""):  errs.append("description still TODO")
print("OK" if not errs else "ERRS:" + "||".join(errs))
PY
)"

case "$struct" in
  "MISSING_YAML") note_fail "PyYAML missing — pip install pyyaml" ;;
  PARSE_ERROR:*)  note_fail "action.yml parse error: ${struct#PARSE_ERROR: }" ;;
  "OK")           note_ok "action.yml structure valid" ;;
  ERRS:*)
    IFS='|' read -ra parts <<< "${struct#ERRS:}"
    for p in "${parts[@]}"; do [ -n "$p" ] && note_fail "structure: $p"; done
    ;;
  *) note_fail "unexpected structure output: $struct" ;;
esac

# ---------- Check 2: dist/index.js exists ----------
if [ -f "$ACTION/dist/index.js" ]; then
  note_ok "dist/index.js present"
else
  note_fail "dist/index.js missing (copy from src/ or run 'npm run build')"
fi

# ---------- Check 2b: src uses @actions/core ----------
if [ -f "$ACTION/src/index.js" ] && grep -q "require('@actions/core')" "$ACTION/src/index.js"; then
  note_ok "src/index.js uses @actions/core"
else
  note_fail "src/index.js should 'require(\"@actions/core\")'"
fi

# ---------- Dynamic checks require node ----------
if ! command -v node >/dev/null 2>&1; then
  echo
  printf "%b" "$report"
  echo
  echo "WARN: node not installed; skipping dynamic checks."
  echo "Install Node 20+ (nodejs.org or 'brew install node') and rerun."
  exit 1
fi

if [ ! -f "$ACTION/dist/index.js" ]; then
  echo
  printf "%b" "$report"
  echo "RESULT: cannot run dynamic checks without dist/index.js."
  exit 1
fi

run_action() {
  local path="$1" pattern="$2" threshold="$3"
  local out="$BASE/gh_output.$$"
  : > "$out"
  (
    cd "$ACTION"
    GITHUB_OUTPUT="$out" \
      INPUT_PATH="$path" \
      INPUT_PATTERN="$pattern" \
      INPUT_FAIL_THRESHOLD="$threshold" \
      node dist/index.js
  )
  local rc=$?
  echo "RC=$rc"
  cat "$out"
  rm -f "$out"
  return $rc
}

# ---------- Check 3: default pattern over fixtures ----------
echo "-- run A: INPUT_PATH=./fixtures --"
out="$(run_action "./fixtures" "**/*" "0" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
   && echo "$out" | grep -q '^total-lines=18$' \
   && echo "$out" | grep -q '^file-count=3$' \
   && echo "$out" | grep -q '^top-file=.*c\.py$'; then
  note_ok "default pattern: total-lines=18, file-count=3, top-file=*c.py"
else
  note_fail "default pattern wrong (rc=$rc). Got:
$out"
fi

# ---------- Check 4: python-only pattern ----------
echo "-- run B: INPUT_PATH=./fixtures INPUT_PATTERN=**/*.py --"
out="$(run_action "./fixtures" "**/*.py" "0" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
   && echo "$out" | grep -q '^total-lines=10$' \
   && echo "$out" | grep -q '^file-count=1$' \
   && echo "$out" | grep -q '^top-file=.*c\.py$'; then
  note_ok "pattern **/*.py: total-lines=10, file-count=1, top-file=*c.py"
else
  note_fail "pattern **/*.py gave wrong result (rc=$rc). Got:
$out"
fi

# ---------- Check 5: fail-threshold ----------
echo "-- run C: INPUT_FAIL_THRESHOLD=5 (total 18 > 5) --"
out="$(run_action "./fixtures" "**/*" "5" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  note_ok "fail-threshold=5 with total=18 → rc!=0"
else
  note_fail "fail-threshold=5 with total=18 should exit non-zero; got rc=$rc, output:
$out"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
