#!/usr/bin/env bash
# Validator for k8s-12-01-write-rbac-for-ci-user.
# Not using `set -o pipefail` — grep -q after long producers can SIGPIPE
# and give false negatives.
set -u

BASE="${1:-${BASE_DIR:-/tmp/k8s-12-01}}"
CTX="kind-k8s-12-01"
NS="apps"
SA="ci-deployer"
USER_STR="system:serviceaccount:${NS}:${SA}"
ADR="$BASE/manifests/apps-rbac.md"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating RBAC for $USER_STR on cluster $CTX =="

# Preflight
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not in PATH" >&2
  exit 2
fi

if ! kubectl --context "$CTX" cluster-info >/dev/null 2>&1; then
  bad "cluster context '$CTX' not reachable (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

# Namespace exists
if kubectl --context "$CTX" get ns "$NS" >/dev/null 2>&1; then
  ok "namespace '$NS' exists"
else
  bad "namespace '$NS' does not exist"
fi

# SA exists
if kubectl --context "$CTX" -n "$NS" get sa "$SA" >/dev/null 2>&1; then
  ok "ServiceAccount '$SA' exists in '$NS'"
else
  bad "ServiceAccount '$SA' not found in '$NS'"
fi

# automountServiceAccountToken explicitly false
automount="$(kubectl --context "$CTX" -n "$NS" get sa "$SA" -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null || true)"
if [ "$automount" = "false" ]; then
  ok "ServiceAccount has automountServiceAccountToken: false"
else
  bad "ServiceAccount should set automountServiceAccountToken: false (got: '${automount:-<unset>}')"
fi

# No ClusterRoleBinding to cluster-admin for this SA
crb_bad="$(kubectl --context "$CTX" get clusterrolebinding -o json \
  | python3 -c '
import json, sys
data = json.load(sys.stdin)
bad = []
for item in data.get("items", []):
    role = item.get("roleRef", {})
    if role.get("name") == "cluster-admin":
        for s in item.get("subjects") or []:
            if s.get("kind") == "ServiceAccount" and s.get("namespace") == "apps" and s.get("name") == "ci-deployer":
                bad.append(item["metadata"]["name"])
print("\n".join(bad))
' 2>/dev/null)"
if [ -z "$crb_bad" ]; then
  ok "no ClusterRoleBinding grants cluster-admin to ci-deployer"
else
  bad "ClusterRoleBinding(s) grant cluster-admin to ci-deployer: $crb_bad"
fi

# Positive permissions (should be allowed)
check_can() {
  local verb="$1"
  local resource="$2"
  local want="$3"      # yes | no
  local label="$4"
  local got
  got="$(kubectl --context "$CTX" auth can-i "$verb" "$resource" -n "$NS" --as="$USER_STR" 2>/dev/null)"
  got="${got:-no}"
  if [ "$got" = "$want" ]; then
    ok "$label (can-i $verb $resource → $got)"
  else
    bad "$label (expected $want, got $got)"
  fi
}

check_can list    deployments.apps  yes "ci-deployer can list Deployments"
check_can create  deployments.apps  yes "ci-deployer can create Deployments"
check_can patch   deployments.apps  yes "ci-deployer can patch Deployments"
check_can list    pods              yes "ci-deployer can list Pods"
check_can get     pods/log          yes "ci-deployer can read Pod logs"
check_can create  services          yes "ci-deployer can create Services"
check_can list    replicasets.apps  yes "ci-deployer can list ReplicaSets"

# Negative permissions (must be denied)
check_can get     secrets           no  "ci-deployer CANNOT read Secrets in apps"
check_can list    secrets           no  "ci-deployer CANNOT list Secrets in apps"
check_can create  roles.rbac.authorization.k8s.io no "ci-deployer CANNOT create Roles"
check_can create  rolebindings.rbac.authorization.k8s.io no "ci-deployer CANNOT create RoleBindings"

# Negative cluster-scope (nodes, cross-namespace secrets)
got_nodes="$(kubectl --context "$CTX" auth can-i patch nodes --as="$USER_STR" 2>/dev/null)"
got_nodes="${got_nodes:-no}"
if [ "$got_nodes" = "no" ]; then
  ok "ci-deployer CANNOT patch Nodes (cluster-scope)"
else
  bad "ci-deployer should NOT patch Nodes (got $got_nodes)"
fi

got_ks="$(kubectl --context "$CTX" auth can-i get secrets -n kube-system --as="$USER_STR" 2>/dev/null)"
got_ks="${got_ks:-no}"
if [ "$got_ks" = "no" ]; then
  ok "ci-deployer CANNOT read Secrets in kube-system"
else
  bad "ci-deployer should NOT read Secrets in kube-system (got $got_ks)"
fi

# ADR exists with required sections
if [ ! -f "$ADR" ]; then
  bad "ADR missing at $ADR"
else
  ok "ADR file exists"
  missing=""
  for section in '## Status' '## Context' '## Decision' '## Consequences'; do
    if ! grep -qF "$section" "$ADR"; then
      missing+=" '$section'"
    fi
  done
  if [ -z "$missing" ]; then
    ok "ADR has required sections (Status, Context, Decision, Consequences)"
  else
    bad "ADR missing sections:$missing"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
