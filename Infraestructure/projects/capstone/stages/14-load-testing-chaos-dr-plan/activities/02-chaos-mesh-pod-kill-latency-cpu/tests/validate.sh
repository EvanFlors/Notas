#!/usr/bin/env bash
# Structural validator for cap-14-02-chaos-mesh-pod-kill-latency-cpu.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
STAGE="$(cd "$ACT/../.." && pwd)"
fail=0

echo "== Validating cap-14-02-chaos-mesh-pod-kill-latency-cpu =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required"
  exit 2
fi

for f in pod-kill.yaml latency-inject.yaml cpu-stress.yaml; do
  p="$STAGE/chaos/$f"
  if [ ! -f "$p" ]; then
    echo "  FAIL $p missing"
    fail=$((fail+1))
    continue
  fi
  echo "  OK   $p exists"

  python3 - "$p" <<'PY' > /tmp/cap-14-02-check.$$ 2>&1 || true
import sys, yaml
try:
    doc = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print("PYERR", e); sys.exit(0)
if not isinstance(doc, dict):
    print("STRUCT_FAIL"); sys.exit(0)
api = doc.get("apiVersion", "")
kind = doc.get("kind", "")
ns = (doc.get("metadata") or {}).get("namespace")
sel = ((doc.get("spec") or {}).get("selector") or {})
nss = sel.get("namespaces") or []
if "chaos-mesh.org" not in api:
    print("API_FAIL", api)
else:
    print("OK api", api)
if kind not in ("PodChaos", "NetworkChaos", "StressChaos"):
    print("KIND_FAIL", kind)
else:
    print("OK kind", kind)
if ns != "app":
    print("NS_FAIL", ns)
else:
    print("OK ns app")
if "app" not in nss:
    print("SEL_FAIL", nss)
else:
    print("OK selector app")
PY
  while IFS= read -r line; do
    case "$line" in
      "OK "*) echo "    OK   $f: ${line#OK }" ;;
      "API_FAIL"*) echo "    FAIL $f apiVersion not chaos-mesh.org: ${line#API_FAIL }"; fail=$((fail+1)) ;;
      "KIND_FAIL"*) echo "    FAIL $f kind not chaos CRD: ${line#KIND_FAIL }"; fail=$((fail+1)) ;;
      "NS_FAIL"*) echo "    FAIL $f metadata.namespace must be 'app': ${line#NS_FAIL }"; fail=$((fail+1)) ;;
      "SEL_FAIL"*) echo "    FAIL $f spec.selector.namespaces must include 'app': ${line#SEL_FAIL }"; fail=$((fail+1)) ;;
      "STRUCT_FAIL"*) echo "    FAIL $f structural"; fail=$((fail+1)) ;;
      "PYERR"*) echo "    FAIL $f parser error: $line"; fail=$((fail+1)) ;;
    esac
  done < /tmp/cap-14-02-check.$$
  rm -f /tmp/cap-14-02-check.$$
done

if [ ! -f "$STAGE/chaos/run-experiment.sh" ]; then
  echo "  FAIL chaos/run-experiment.sh missing"
  fail=$((fail+1))
else
  echo "  OK   chaos/run-experiment.sh exists"
  if grep -q "SKIP" "$STAGE/chaos/run-experiment.sh"; then
    echo "  OK   run-experiment.sh has SKIP branch"
  else
    echo "  FAIL run-experiment.sh must SKIP when kubectl/CRDs missing"
    fail=$((fail+1))
  fi
fi

# experiments.md must cover all 3 experiments.
EXP=""
for cand in "$ACT/experiments.md" "$ACT/starter/experiments.md"; do
  if [ -f "$cand" ]; then EXP="$cand"; break; fi
done
if [ -z "$EXP" ]; then
  echo "  FAIL experiments.md missing"
  fail=$((fail+1))
else
  echo "  OK   experiments.md at $EXP"
  for section in "pod-kill" "latency-inject" "cpu-stress"; do
    if grep -Eq "^##[[:space:]]+${section}" "$EXP"; then
      echo "  OK   experiments.md covers '## $section'"
    else
      echo "  FAIL experiments.md missing '## $section'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida."
exit 0
