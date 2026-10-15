#!/usr/bin/env bash
# Validate gha-12-01-write-composite-action.
#
# Checks:
#   1. action.yml parses as YAML and has the required structure.
#   2. Simulating the runner for inputs 1.2.3 / v1.2.3 / abc produces the
#      correct outputs in $GITHUB_OUTPUT.
#   3. fail-on-invalid=true causes a non-zero exit on an invalid version.
#
# NOTE: deliberately no `set -o pipefail`; some checks pipe long producers
# (git log / cat) into grep -q which can produce SIGPIPE (141) and would be
# mis-reported as failures. Also NOTE: bash 3.2 (default on macOS) breaks on
# heredocs inside $(), so we materialize python helpers to temp files first.

BASE="${1:-${BASE_DIR:-/tmp/composite-action-lab}}"
ACTION_DIR="$BASE/semver-check"
ACTION_YML="$ACTION_DIR/action.yml"

passed=0; failed=0; report=""
note_ok()   { report+="  OK   - $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL - $1\n"; failed=$((failed+1)); }

echo "== Validating $ACTION_YML =="

if [ ! -f "$ACTION_YML" ]; then
  echo "FAIL: $ACTION_YML not found. Run starter/bootstrap.sh first." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required to parse YAML." >&2
  exit 2
fi

TMPDIR_LAB="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LAB"' EXIT

# ---------- Check 1: structure ----------
STRUCT_PY="$TMPDIR_LAB/check_action.py"
cat > "$STRUCT_PY" <<'PY'
import sys, re
try:
    import yaml
except ImportError:
    print("MISSING_YAML"); sys.exit(0)

try:
    data = yaml.safe_load(open(sys.argv[1]).read())
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)

errs = []
if not isinstance(data, dict): errs.append("root is not a mapping")
for key in ("name","description","inputs","outputs","runs"):
    if key not in data: errs.append(f"missing top-level: {key}")

if "PLACEHOLDER" in (data.get("name","") or ""):
    errs.append("name still a placeholder")
if "TODO" in (data.get("name","") or "") or "TODO" in (data.get("description","") or ""):
    errs.append("name/description still TODO")

runs = data.get("runs") or {}
if runs.get("using") != "composite":
    errs.append(f"runs.using must be 'composite', got {runs.get('using')!r}")
steps = runs.get("steps") or []
if not steps:
    errs.append("runs.steps empty")
check_step = next((s for s in steps if s.get("id") == "check"), None)
if not check_step:
    errs.append("no step with id: check")

inputs = data.get("inputs") or {}
for i in ("version", "fail-on-invalid"):
    if i not in inputs: errs.append(f"missing input: {i}")

outputs = data.get("outputs") or {}
for o in ("is-valid","major","minor","patch","normalized"):
    if o not in outputs:
        errs.append(f"missing output: {o}")
    else:
        val = (outputs[o] or {}).get("value","")
        if not re.match(r"\$\{\{\s*steps\.check\.outputs\." + re.escape(o) + r"\s*\}\}", val or ""):
            errs.append(f"output {o}.value does not reference steps.check.outputs.{o}")

if check_step:
    run_block = check_step.get("run","") or ""
    if "${{" in run_block and "inputs." in run_block:
        errs.append("inputs.* interpolated inside run: (use env: instead - anti script injection)")
    env_block = check_step.get("env") or {}
    if "VERSION" not in env_block:
        errs.append("step.env must expose VERSION (via inputs.version)")

if errs:
    print("ERRS:" + "||".join(errs))
else:
    print("OK")
PY

struct_out=$(python3 "$STRUCT_PY" "$ACTION_YML" 2>&1)

case "$struct_out" in
  "MISSING_YAML")
    note_fail "python3 PyYAML not available - install with: pip install pyyaml"
    ;;
  PARSE_ERROR:*)
    note_fail "action.yml YAML parse error: ${struct_out#PARSE_ERROR: }"
    ;;
  "OK")
    note_ok "action.yml structure valid (metadata, inputs, outputs, runs.steps, env usage)"
    ;;
  ERRS:*)
    IFS='|' read -ra parts <<< "${struct_out#ERRS:}"
    for p in "${parts[@]}"; do
      [ -n "$p" ] && note_fail "structure: $p"
    done
    ;;
  *)
    note_fail "unexpected structure checker output: $struct_out"
    ;;
esac

# ---------- Check 2+3: simulate the runner ----------
EXTRACT_PY="$TMPDIR_LAB/extract_run.py"
cat > "$EXTRACT_PY" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]).read())
for s in (d.get("runs") or {}).get("steps") or []:
    if s.get("id") == "check":
        sys.stdout.write(s.get("run",""))
        break
PY

simulate() {
  local version="$1" fail_on_invalid="$2"
  local out="$TMPDIR_LAB/gh_output.$$"
  : > "$out"
  local run_block
  run_block=$(python3 "$EXTRACT_PY" "$ACTION_YML")
  if [ -z "$run_block" ]; then
    echo "NO_RUN_BLOCK"
    return 99
  fi
  GITHUB_OUTPUT="$out" VERSION="$version" FAIL="$fail_on_invalid" \
    bash -c "$run_block"
  local rc=$?
  echo "RC=$rc"
  cat "$out"
  rm -f "$out"
  return $rc
}

# Case A: valid 1.2.3
echo "-- simulate: version=1.2.3, fail=false --"
sim_out=$(simulate "1.2.3" "false" 2>&1); sim_rc=$?
if [ "$sim_rc" -eq 0 ] \
   && echo "$sim_out" | grep -q '^is-valid=true$' \
   && echo "$sim_out" | grep -q '^major=1$' \
   && echo "$sim_out" | grep -q '^minor=2$' \
   && echo "$sim_out" | grep -q '^patch=3$' \
   && echo "$sim_out" | grep -q '^normalized=v1\.2\.3$'; then
  note_ok "valid '1.2.3' produces is-valid=true + components + normalized=v1.2.3"
else
  note_fail "valid '1.2.3' did not produce expected outputs (rc=$sim_rc). Got: $sim_out"
fi

# Case B: invalid 'v1.2.3' with fail=false
echo "-- simulate: version=v1.2.3, fail=false --"
sim_out=$(simulate "v1.2.3" "false" 2>&1); sim_rc=$?
if [ "$sim_rc" -eq 0 ] && echo "$sim_out" | grep -q '^is-valid=false$'; then
  note_ok "invalid 'v1.2.3' with fail=false - is-valid=false and rc=0"
else
  note_fail "invalid 'v1.2.3' handling wrong (rc=$sim_rc). Got: $sim_out"
fi

# Case C: invalid 'abc' with fail=true
echo "-- simulate: version=abc, fail=true --"
sim_out=$(simulate "abc" "true" 2>&1); sim_rc=$?
if [ "$sim_rc" -ne 0 ] && echo "$sim_out" | grep -q '^is-valid=false$'; then
  note_ok "invalid 'abc' with fail=true - rc!=0 and is-valid=false emitted"
else
  note_fail "invalid 'abc' with fail=true should exit non-zero; got rc=$sim_rc, output: $sim_out"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
