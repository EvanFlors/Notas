#!/usr/bin/env bash
# Validate activity argo-05-02-add-migration-presync.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# below use `... | grep -q ...`, which can cause the upstream producer to receive
# SIGPIPE (exit 141) once grep finds its first match and closes the pipe.
# pipefail would spuriously fail those checks.

BASE="${1:-${BASE_DIR:-/tmp/argo05-act02}}"
JOB_FILE="$BASE/app/migration-job.yaml"

passed=0
failed=0
skipped=0
report=""

pass() { report+="  OK:   $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL: $1\n"; failed=$((failed+1)); }
skip() { report+="  SKIP: $1\n"; skipped=$((skipped+1)); }

echo "== argo-05-02 validator =="
echo "base: $BASE"

if [ ! -f "$JOB_FILE" ]; then
  fail "missing file: $JOB_FILE"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed passed / $failed failed / $skipped skipped"
  echo "Hint: crear app/migration-job.yaml con el Job hook; ver teoría §6 y examples/03"
  exit 1
fi
pass "migration-job.yaml exists"

# --- Quick grep-based checks (no pipefail; grep -q is intentional) ---------
if grep -q 'kind:[[:space:]]*Job' "$JOB_FILE"; then
  pass "kind: Job present"
else
  fail "kind: Job missing"
fi

if grep -q 'argocd.argoproj.io/hook:[[:space:]]*PreSync' "$JOB_FILE"; then
  pass "annotation argocd.argoproj.io/hook: PreSync present"
else
  fail "annotation argocd.argoproj.io/hook: PreSync missing"
fi

if grep -q 'argocd.argoproj.io/hook-delete-policy:[[:space:]]*BeforeHookCreation,HookSucceeded' "$JOB_FILE"; then
  pass "annotation hook-delete-policy: BeforeHookCreation,HookSucceeded present"
else
  fail "annotation hook-delete-policy must be BeforeHookCreation,HookSucceeded"
fi

if grep -qE 'backoffLimit:[[:space:]]*0([^0-9]|$)' "$JOB_FILE"; then
  pass "backoffLimit: 0 present"
else
  fail "backoffLimit: 0 missing (retry must be handled by Argo CD syncPolicy.retry, not by the Job)"
fi

if grep -q 'restartPolicy:[[:space:]]*Never' "$JOB_FILE"; then
  pass "restartPolicy: Never present"
else
  fail "restartPolicy: Never required for Job hooks"
fi

# --- Structural validation via Python (SKIP if PyYAML missing) --------------
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  python3 - "$JOB_FILE" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh)
if not isinstance(doc, dict):
    print("FAIL: file is not a single YAML mapping")
    sys.exit(2)
if doc.get("kind") != "Job":
    print(f"FAIL: kind must be Job (got {doc.get('kind')})")
    sys.exit(2)
ann = ((doc.get("metadata") or {}).get("annotations")) or {}
if ann.get("argocd.argoproj.io/hook") != "PreSync":
    print(f"FAIL: annotation hook must be exactly 'PreSync' (got {ann.get('argocd.argoproj.io/hook')!r})")
    sys.exit(2)
if ann.get("argocd.argoproj.io/hook-delete-policy") != "BeforeHookCreation,HookSucceeded":
    print(f"FAIL: hook-delete-policy must be exactly 'BeforeHookCreation,HookSucceeded'")
    sys.exit(2)
spec = doc.get("spec") or {}
if spec.get("backoffLimit") != 0:
    print(f"FAIL: spec.backoffLimit must be 0 (got {spec.get('backoffLimit')!r})")
    sys.exit(2)
rp = ((spec.get("template") or {}).get("spec") or {}).get("restartPolicy")
if rp != "Never":
    print(f"FAIL: template.spec.restartPolicy must be Never (got {rp!r})")
    sys.exit(2)
print("OK: structural YAML checks passed")
sys.exit(0)
PYEOF
  if [ $? -eq 0 ]; then
    pass "structural YAML checks passed"
  else
    fail "structural YAML checks failed (see output above)"
  fi
else
  skip "python3 + PyYAML not available; skipping structural check"
fi

# --- Optional cluster dry-run ----------------------------------------------
if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
  # Namespace must exist for dry-run=server to succeed; create a transient one.
  NS="argo05-act02-dryrun"
  kubectl create ns "$NS" >/dev/null 2>&1 || true
  # Patch namespace reference inline for the dry-run only (write to /tmp).
  TMP="/tmp/argo05-act02-dryrun.yaml"
  sed "s/namespace:[[:space:]]*presync-lab/namespace: $NS/" "$JOB_FILE" > "$TMP"
  if kubectl apply --dry-run=server -f "$TMP" >/dev/null 2>&1; then
    pass "server-side dry-run of the Job succeeded"
  else
    fail "server-side dry-run of the Job failed (invalid Job spec?)"
  fi
  kubectl delete ns "$NS" --wait=false >/dev/null 2>&1 || true
  rm -f "$TMP"
else
  skip "no cluster reachable; skipping server-side dry-run"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed passed / $failed failed / $skipped skipped"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
