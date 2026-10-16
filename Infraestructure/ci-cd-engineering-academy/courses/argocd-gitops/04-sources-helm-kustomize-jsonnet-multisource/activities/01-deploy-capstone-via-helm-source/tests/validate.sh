#!/usr/bin/env bash
# Validate argo-04-01-deploy-capstone-via-helm-source.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which on a match closes the pipe early and causes the
# upstream producer (kubectl, yq, cat) to receive SIGPIPE (exit 141).
# pipefail would mark those as failures.
set -u

CLUSTER=argo-04-01
CTX="kind-$CLUSTER"
STARTER="$(cd "$(dirname "$0")/../starter" && pwd)"
SOLUTION="$(cd "$(dirname "$0")/../solution" && pwd)"

passed=0
failed=0
skipped=0
report=""

note_pass() { report+="OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="FAIL — $1\n"; failed=$((failed+1)); }
note_skip() { report+="SKIP — $1 ($2)\n"; skipped=$((skipped+1)); }

# ----- 0. Toolchain -----
missing=""
for tool in kubectl kind helm python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing="$missing $tool"
  fi
done
if [ -n "$missing" ]; then
  echo "SKIP: missing tools:$missing. Nothing to validate."
  echo "This is expected on machines without a local K8s toolchain."
  exit 0
fi

# ----- 1. starter/application.yaml is valid YAML -----
if python3 -c "import yaml,sys; list(yaml.safe_load_all(open('$STARTER/application.yaml')))" 2>/dev/null; then
  note_pass "starter/application.yaml is valid YAML"
else
  note_fail "starter/application.yaml is not valid YAML"
fi

# ----- 2. starter/application.yaml has had the TODOs resolved -----
if grep -q 'TODO' "$STARTER/application.yaml"; then
  note_fail "starter/application.yaml still contains TODO markers (did you complete section 5.3?)"
else
  note_pass "starter/application.yaml has no leftover TODOs"
fi

# ----- 3. solution/application.yaml is also parseable (sanity) -----
if python3 -c "import yaml; d=list(yaml.safe_load_all(open('$SOLUTION/application.yaml'))); assert d[0]['spec']['source']['helm']['releaseName']=='podinfo'" 2>/dev/null; then
  note_pass "solution references releaseName: podinfo"
else
  note_fail "solution is missing or wrong (expected releaseName: podinfo)"
fi

# ----- 4. kind cluster exists -----
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  note_pass "kind cluster '$CLUSTER' exists"
else
  note_skip "kind cluster '$CLUSTER' missing" "did you run 01-create-cluster.sh?"
  # Early return — remaining checks need the cluster.
  echo
  printf "%b" "$report"
  echo
  echo "Summary: $passed passed, $failed failed, $skipped skipped."
  [ "$failed" -eq 0 ] && exit 0 || exit 1
fi

# ----- 5. argocd namespace up -----
if kubectl --context "$CTX" get ns argocd >/dev/null 2>&1; then
  note_pass "namespace argocd exists"
else
  note_skip "argocd namespace missing" "did you run 02-install-argocd.sh?"
fi

# ----- 6. Application has been applied -----
if kubectl --context "$CTX" -n argocd get application podinfo >/dev/null 2>&1; then
  note_pass "Application podinfo exists in argocd namespace"
else
  note_skip "Application podinfo not found" "apply starter/application.yaml"
  echo
  printf "%b" "$report"
  echo
  echo "Summary: $passed passed, $failed failed, $skipped skipped."
  [ "$failed" -eq 0 ] && exit 0 || exit 1
fi

# ----- 7. Deployment podinfo exists and is Available -----
if kubectl --context "$CTX" -n podinfo get deployment podinfo >/dev/null 2>&1; then
  avail="$(kubectl --context "$CTX" -n podinfo get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)"
  if [ "${avail:-0}" -ge 1 ]; then
    note_pass "Deployment podinfo has $avail available replica(s)"
  else
    note_fail "Deployment podinfo not Available yet (availableReplicas=$avail)"
  fi
else
  note_fail "Deployment podinfo not found in namespace podinfo"
fi

# ----- 8. KEY POINT: helm does NOT see this release -----
#   helm list exits 0 even with no releases, so check its output.
if command -v helm >/dev/null 2>&1; then
  if helm --kube-context "$CTX" list -n podinfo 2>/dev/null | grep -qw 'podinfo'; then
    note_fail "helm list DOES see 'podinfo' — unexpected (did you run 'helm install' by mistake?)"
  else
    note_pass "helm list -n podinfo does NOT see the release (Argo CD rendered + applied; no helm release Secret)"
  fi
fi

# ----- 9. Image tag was applied via parameters -----
tag="$(kubectl --context "$CTX" -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
if printf '%s' "$tag" | grep -q ':6.7.1'; then
  note_pass "Deployment image pinned to 6.7.1 (parameters took effect): $tag"
else
  note_fail "Deployment image tag unexpected: '$tag' (expected :6.7.1)"
fi

echo
printf "%b" "$report"
echo
echo "Summary: $passed passed, $failed failed, $skipped skipped."
[ "$failed" -eq 0 ] && exit 0 || exit 1
