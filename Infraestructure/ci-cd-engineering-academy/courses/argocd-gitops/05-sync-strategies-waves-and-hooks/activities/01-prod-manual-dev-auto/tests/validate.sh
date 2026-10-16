#!/usr/bin/env bash
# Validate activity argo-05-01-prod-manual-dev-auto.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# below use `... | grep -q ...`, which can cause the upstream producer to receive
# SIGPIPE (exit 141) once grep finds its first match and closes the pipe.
# pipefail would spuriously fail those checks.

BASE="${1:-${BASE_DIR:-/tmp/argo05-act01}}"
DEV_APP="$BASE/apps/web-dev.yaml"
PROD_APP="$BASE/apps/web-prod.yaml"
PROD_PROJ="$BASE/projects/prod.yaml"

passed=0
failed=0
skipped=0
report=""

pass() { report+="  OK:   $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL: $1\n"; failed=$((failed+1)); }
skip() { report+="  SKIP: $1\n"; skipped=$((skipped+1)); }

echo "== argo-05-01 validator =="
echo "base: $BASE"

# --- Check 0: files exist ---------------------------------------------------
missing=0
for f in "$DEV_APP" "$PROD_APP" "$PROD_PROJ"; do
  if [ ! -f "$f" ]; then
    fail "missing file: $f"
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed passed / $failed failed / $skipped skipped"
  echo "Hint: cp -r starter/* $BASE/"
  exit 1
fi
pass "all three files present"

# --- Need Python + PyYAML for structural checks ----------------------------
if ! command -v python3 >/dev/null 2>&1; then
  skip "python3 not available; skipping structural checks"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed passed / $failed failed / $skipped skipped"
  exit 0
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  skip "PyYAML not available; skipping structural checks (install with: pip install pyyaml)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed passed / $failed failed / $skipped skipped"
  exit 0
fi

# --- Structural checks via Python ------------------------------------------
python3 - "$DEV_APP" "$PROD_APP" "$PROD_PROJ" <<'PYEOF'
import sys, yaml, json

dev_path, prod_path, proj_path = sys.argv[1], sys.argv[2], sys.argv[3]
results = []

def ok(msg):   results.append(("OK", msg))
def bad(msg):  results.append(("FAIL", msg))

def load(path):
    with open(path) as fh:
        return yaml.safe_load(fh)

try:
    dev  = load(dev_path)
    prod = load(prod_path)
    proj = load(proj_path)
except Exception as e:
    print(f"FAIL: YAML parse error: {e}")
    sys.exit(2)

# --- web-dev checks ---
sp = (dev.get("spec") or {}).get("syncPolicy") or {}
auto = sp.get("automated") or {}
if auto.get("prune") is True and auto.get("selfHeal") is True:
    ok("web-dev: automated.prune=true and automated.selfHeal=true")
else:
    bad(f"web-dev: automated must have prune=true and selfHeal=true (got: {auto})")

opts = sp.get("syncOptions") or []
need = {"CreateNamespace=true", "ServerSideApply=true"}
missing = need - set(opts)
if not missing:
    ok("web-dev: syncOptions include CreateNamespace=true and ServerSideApply=true")
else:
    bad(f"web-dev: missing syncOptions: {sorted(missing)} (got: {opts})")

# --- web-prod checks ---
spp = (prod.get("spec") or {}).get("syncPolicy") or {}
if "automated" not in spp:
    ok("web-prod: no automated block (manual sync as required)")
else:
    bad("web-prod: must NOT have syncPolicy.automated (prod is manual)")

optsp = spp.get("syncOptions") or []
need_p = {"ServerSideApply=true", "PruneLast=true"}
missing_p = need_p - set(optsp)
if not missing_p:
    ok("web-prod: syncOptions include ServerSideApply=true and PruneLast=true")
else:
    bad(f"web-prod: missing syncOptions: {sorted(missing_p)} (got: {optsp})")

# --- AppProject prod checks ---
wins = ((proj.get("spec") or {}).get("syncWindows")) or []
deny_wins = [w for w in wins if w.get("kind") == "deny"]
if deny_wins:
    ok(f"AppProject prod: has {len(deny_wins)} deny sync window(s)")
    # at least one must have manualSync: true
    if any(w.get("manualSync") is True for w in deny_wins):
        ok("AppProject prod: at least one deny window has manualSync=true (hotfix path)")
    else:
        bad("AppProject prod: no deny window has manualSync=true (hotfix impossible)")
    # applications must include web-prod (or be absent/wildcard)
    scoped = any(("web-prod" in (w.get("applications") or [])) or not w.get("applications") for w in deny_wins)
    if scoped:
        ok("AppProject prod: a deny window applies to web-prod")
    else:
        bad("AppProject prod: no deny window targets web-prod")
else:
    bad("AppProject prod: no deny sync window found (spec.syncWindows missing or empty)")

for status, msg in results:
    print(f"{status}: {msg}")
sys.exit(0 if not any(s == "FAIL" for s, _ in results) else 1)
PYEOF
PY_RC=$?

# Attach python-reported results into the report
echo
printf "%b" "$report"

if [ "$PY_RC" -eq 0 ]; then
  echo "Structural checks: PASS"
else
  echo "Structural checks: FAIL"
  failed=$((failed+1))
fi

# --- Optional cluster checks (SKIP gracefully) ------------------------------
echo
if command -v kubectl >/dev/null 2>&1 && kubectl version --client >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
      echo "Cluster + Argo CD CRDs detected; validating with --dry-run=server..."
      if kubectl apply -n argocd -f "$PROD_PROJ" --dry-run=server >/dev/null 2>&1 \
         && kubectl apply -n argocd -f "$DEV_APP" --dry-run=server >/dev/null 2>&1 \
         && kubectl apply -n argocd -f "$PROD_APP" --dry-run=server >/dev/null 2>&1; then
        pass "server-side dry-run succeeded for all three manifests"
      else
        fail "server-side dry-run failed on at least one manifest"
      fi
    else
      skip "Argo CD CRDs not installed; skipping dry-run=server"
    fi
  else
    skip "no cluster reachable; skipping dry-run checks"
  fi
else
  skip "kubectl not available; skipping dry-run checks"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed passed / $failed failed / $skipped skipped"
if [ "$failed" -gt 0 ] || [ "$PY_RC" -ne 0 ]; then
  exit 1
fi
exit 0
