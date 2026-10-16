#!/usr/bin/env bash
# Validate: student completed argo-03-01-write-application-manifest.
# Pass the Application manifest path as first arg; defaults to /tmp/argo-03-01/application.yaml.
#
# Note: `set -o pipefail` deliberately NOT enabled; several checks pipe into
# `grep -q`, which closes the pipe early and would mark the producer as failed.

set -eu

MANIFEST="${1:-/tmp/argo-03-01/application.yaml}"
fail=0

echo "== Validating Application manifest: $MANIFEST =="

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: file does not exist: $MANIFEST"
  echo "Hint: copy starter/application.yaml to /tmp/argo-03-01/ and edit it."
  exit 1
fi

# 1. No TODO left behind
if grep -q 'TODO' "$MANIFEST"; then
  echo "  FAIL manifest still contains TODO placeholders:"
  grep -n 'TODO' "$MANIFEST" | sed 's/^/        /'
  fail=$((fail+1))
else
  echo "  OK   no TODO placeholders remain"
fi

# 2. apiVersion + kind
if grep -q '^apiVersion: argoproj.io/v1alpha1$' "$MANIFEST" \
    && grep -q '^kind: Application$' "$MANIFEST"; then
  echo "  OK   apiVersion + kind correct"
else
  echo "  FAIL apiVersion/kind missing or wrong"
  fail=$((fail+1))
fi

# 3. metadata.namespace: argocd
if grep -qE '^  namespace: argocd$' "$MANIFEST"; then
  echo "  OK   metadata.namespace is 'argocd'"
else
  echo "  FAIL metadata.namespace should be 'argocd' (Application CR lives in Argo CD ns)"
  fail=$((fail+1))
fi

# 4. source fields present and sane
if grep -qE '^    repoURL: https?://' "$MANIFEST"; then
  echo "  OK   source.repoURL present (https URL)"
else
  echo "  FAIL source.repoURL missing or not an https URL"
  fail=$((fail+1))
fi

if grep -qE '^    path: envs/dev/api$' "$MANIFEST"; then
  echo "  OK   source.path = envs/dev/api"
else
  echo "  FAIL source.path should be 'envs/dev/api'"
  fail=$((fail+1))
fi

# 5. targetRevision must NOT be HEAD (pitfall)
tr_line="$(grep -E '^    targetRevision: ' "$MANIFEST" | head -n1 || true)"
if [ -z "$tr_line" ]; then
  echo "  FAIL source.targetRevision missing"
  fail=$((fail+1))
elif echo "$tr_line" | grep -qE 'targetRevision: HEAD$'; then
  echo "  FAIL source.targetRevision is 'HEAD' — pitfall for stg/prod. Use a branch (e.g. 'main')."
  fail=$((fail+1))
else
  echo "  OK   source.targetRevision set and not HEAD ($(echo "$tr_line" | sed 's/^    //'))"
fi

# 6. destination
if grep -qE '^    server: https://kubernetes.default.svc$' "$MANIFEST"; then
  echo "  OK   destination.server = in-cluster"
else
  echo "  FAIL destination.server should be 'https://kubernetes.default.svc'"
  fail=$((fail+1))
fi
if grep -qE '^    namespace: capstone-dev$' "$MANIFEST"; then
  echo "  OK   destination.namespace = capstone-dev"
else
  echo "  FAIL destination.namespace should be 'capstone-dev'"
  fail=$((fail+1))
fi

# 7. syncPolicy.automated.prune and selfHeal
if grep -qE '^      prune: true$' "$MANIFEST"; then
  echo "  OK   automated.prune: true"
else
  echo "  FAIL automated.prune must be true"
  fail=$((fail+1))
fi
if grep -qE '^      selfHeal: true$' "$MANIFEST"; then
  echo "  OK   automated.selfHeal: true"
else
  echo "  FAIL automated.selfHeal must be true"
  fail=$((fail+1))
fi

# 8. syncOptions must include the three required flags
for opt in 'CreateNamespace=true' 'ServerSideApply=true' 'RespectIgnoreDifferences=true'; do
  if grep -qE "^      - $opt$" "$MANIFEST"; then
    echo "  OK   syncOptions contains $opt"
  else
    echo "  FAIL syncOptions must contain '$opt'"
    fail=$((fail+1))
  fi
done

# 9. ignoreDifferences must mention /spec/replicas on apps/Deployment
has_ignore=0
if grep -q '^  ignoreDifferences:' "$MANIFEST" \
   && grep -q '/spec/replicas' "$MANIFEST" \
   && grep -q 'kind: Deployment' "$MANIFEST" \
   && grep -q 'group: apps' "$MANIFEST"; then
  has_ignore=1
fi
if [ "$has_ignore" -eq 1 ]; then
  echo "  OK   ignoreDifferences targets /spec/replicas on apps/Deployment"
else
  echo "  FAIL ignoreDifferences must include /spec/replicas on apps/Deployment"
  fail=$((fail+1))
fi

# 10. Client-side kubectl dry-run (syntactic)
if command -v kubectl >/dev/null 2>&1; then
  if kubectl apply --dry-run=client --validate=false -f "$MANIFEST" >/dev/null 2>&1; then
    echo "  OK   kubectl --dry-run=client parsed the manifest"
  else
    echo "  WARN kubectl --dry-run=client did NOT parse the manifest; details:"
    kubectl apply --dry-run=client --validate=false -f "$MANIFEST" 2>&1 | sed 's/^/        /' || true
    # Not counted as fail: environment may lack kubectl-ok CRDs; treat as advisory.
  fi
else
  echo "  SKIP kubectl not installed; cannot run --dry-run=client"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
