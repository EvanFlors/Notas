#!/usr/bin/env bash
# Validate the bootstrap lab. Six checks:
#   LAYOUT (always):
#     1) repo rendered at $BASE/bootstrap-repo with the canonical layout
#     2) root.yaml is an ApplicationSet, not a plain Application
#     3) argo-cd Application has selfHeal: false AND prune: false
#   CLUSTER (skipped if contexts not present — e.g. --layout-only or constrained env):
#     4) hub has argocd namespace with argocd-server deployment Available
#     5) hub has at least the Applications argo-cd, metrics-server, guestbook
#     6) hub has a cluster Secret with the required label (either spoke or in-cluster-only)
#
# Note: we DO NOT set `pipefail` because several checks use `grep -q` on long outputs
# where SIGPIPE on the upstream producer is normal and would spuriously fail.
set -eu

BASE="${BASE:-/tmp/argo08}"
REPO="$BASE/bootstrap-repo"
HUB="${HUB_CONTEXT:-kind-argo08-hub}"

passed=0
failed=0
skipped=0
report=""

ok()     { report+="  OK   — $1\n"; passed=$((passed+1)); }
fail()   { report+="  FAIL — $1\n"; failed=$((failed+1)); }
skip()   { report+="  SKIP — $1\n"; skipped=$((skipped+1)); }

# ------------------------------------------------------------------------------
# Check 1 — repo layout exists
# ------------------------------------------------------------------------------
check_layout() {
  local missing=""
  for f in \
    "$REPO/bootstrap/root.yaml" \
    "$REPO/projects/platform.yaml" \
    "$REPO/addons/argo-cd/application.yaml" \
    "$REPO/addons/metrics-server/application.yaml" \
    "$REPO/apps/guestbook/application.yaml"
  do
    [ -f "$f" ] || missing+=" $f"
  done
  if [ -z "$missing" ]; then
    ok "layout — all expected files present under $REPO"
  else
    fail "layout — missing:$missing"
  fi
}

# ------------------------------------------------------------------------------
# Check 2 — root is an ApplicationSet (not plain Application)
# ------------------------------------------------------------------------------
check_root_kind() {
  local root="$REPO/bootstrap/root.yaml"
  if [ ! -f "$root" ]; then
    fail "root.yaml missing — cannot verify kind"
    return
  fi
  if grep -q '^kind: ApplicationSet$' "$root"; then
    ok "root.yaml is an ApplicationSet"
  else
    fail "root.yaml is not an ApplicationSet (want: kind: ApplicationSet)"
  fi
}

# ------------------------------------------------------------------------------
# Check 3 — Argo CD self-managing Application has selfHeal:false AND prune:false
# ------------------------------------------------------------------------------
check_argocd_guardrails() {
  local f="$REPO/addons/argo-cd/application.yaml"
  if [ ! -f "$f" ]; then
    fail "addons/argo-cd/application.yaml missing"
    return
  fi
  local sh pr
  sh=$(grep -E '^[[:space:]]*selfHeal:[[:space:]]*false' "$f" | head -1 || true)
  pr=$(grep -E '^[[:space:]]*prune:[[:space:]]*false'    "$f" | head -1 || true)
  if [ -n "$sh" ] && [ -n "$pr" ]; then
    ok "argo-cd Application has selfHeal:false AND prune:false (chicken-and-egg guardrails)"
  else
    local why=""
    [ -z "$sh" ] && why+=" selfHeal is not false;"
    [ -z "$pr" ] && why+=" prune is not false;"
    fail "argo-cd Application missing guardrails —$why"
  fi
}

# ------------------------------------------------------------------------------
# Check 4 — hub cluster has argocd running
# ------------------------------------------------------------------------------
check_hub_argocd() {
  if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$HUB"; then
    skip "hub context '$HUB' not present (run starter/bootstrap.sh without --layout-only)"
    return
  fi
  if ! kubectl --context "$HUB" get ns argocd >/dev/null 2>&1; then
    fail "hub '$HUB' has no namespace 'argocd'"
    return
  fi
  if kubectl --context "$HUB" -n argocd get deploy argocd-server >/dev/null 2>&1; then
    local ready
    ready=$(kubectl --context "$HUB" -n argocd get deploy argocd-server \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")
    if [ "${ready:-0}" -ge 1 ]; then
      ok "hub argocd-server has ${ready} ready replica(s)"
    else
      fail "hub argocd-server exists but has 0 ready replicas"
    fi
  else
    fail "hub has no argocd-server deployment"
  fi
}

# ------------------------------------------------------------------------------
# Check 5 — hub has the expected Applications
# ------------------------------------------------------------------------------
check_hub_apps() {
  if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$HUB"; then
    skip "hub context '$HUB' not present — Applications check"
    return
  fi
  if ! kubectl --context "$HUB" get crd applications.argoproj.io >/dev/null 2>&1; then
    fail "Application CRD not present on hub (Argo CD not installed?)"
    return
  fi
  local names
  names=$(kubectl --context "$HUB" -n argocd get applications -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  local missing=""
  for app in argo-cd metrics-server guestbook; do
    echo " $names " | grep -q " $app " || missing+=" $app"
  done
  if [ -z "$missing" ]; then
    ok "hub Applications present: argo-cd, metrics-server, guestbook"
  else
    fail "hub missing Applications:$missing (have: $names)"
  fi
}

# ------------------------------------------------------------------------------
# Check 6 — hub has a cluster Secret with correct label (spoke OR in-cluster)
# ------------------------------------------------------------------------------
check_cluster_secret() {
  if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$HUB"; then
    skip "hub context '$HUB' not present — cluster Secret check"
    return
  fi
  local secrets
  secrets=$(kubectl --context "$HUB" -n argocd get secret \
            -l argocd.argoproj.io/secret-type=cluster \
            -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  # When --spoke-only was used, there is no cluster Secret (the built-in in-cluster is
  # implicit). Accept that if the guestbook Application targets the in-cluster server.
  if [ -n "$secrets" ]; then
    ok "cluster Secret(s) with required label present: $secrets"
  else
    local gb="$REPO/apps/guestbook/application.yaml"
    if [ -f "$gb" ] && grep -q 'server: https://kubernetes.default.svc' "$gb"; then
      ok "no explicit cluster Secret, but guestbook targets in-cluster (spoke-only mode)"
    else
      fail "no cluster Secret with label argocd.argoproj.io/secret-type=cluster, and guestbook does not target in-cluster"
    fi
  fi
}

# ------------------------------------------------------------------------------
echo "== validate.sh — base=$BASE hub=$HUB =="

if [ ! -d "$REPO" ]; then
  echo "FAIL: bootstrap repo not found at $REPO — did you run starter/bootstrap.sh?"
  exit 1
fi

check_layout
check_root_kind
check_argocd_guardrails
check_hub_argocd
check_hub_apps
check_cluster_secret

echo
printf "%b" "$report"
echo
total=$((passed + failed + skipped))
echo "RESULT: $passed/$total checks OK  ($failed FAIL, $skipped SKIP)"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
# Treat "all layout OK + all cluster SKIP" as acceptance (layout-only run).
exit 0
