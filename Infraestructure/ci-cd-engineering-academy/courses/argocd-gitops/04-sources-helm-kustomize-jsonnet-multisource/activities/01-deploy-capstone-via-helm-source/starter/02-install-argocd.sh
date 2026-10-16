#!/usr/bin/env bash
# Install Argo CD into the kind cluster.
set -eu

CLUSTER=argo-04-01
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl config get-contexts "kind-$CLUSTER" >/dev/null 2>&1; then
  echo "SKIP: context kind-$CLUSTER not found. Run 01-create-cluster.sh first."
  exit 0
fi

kubectl --context "kind-$CLUSTER" create namespace argocd --dry-run=client -o yaml \
  | kubectl --context "kind-$CLUSTER" apply -f -

echo "Applying Argo CD stable manifests..."
kubectl --context "kind-$CLUSTER" -n argocd apply \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD deployments to become Available (up to 5 min)..."
for d in argocd-server argocd-repo-server argocd-applicationset-controller argocd-redis argocd-dex-server argocd-notifications-controller; do
  if kubectl --context "kind-$CLUSTER" -n argocd get deployment "$d" >/dev/null 2>&1; then
    kubectl --context "kind-$CLUSTER" -n argocd wait --for=condition=available deployment/"$d" --timeout=300s || true
  fi
done

# application-controller is a StatefulSet
if kubectl --context "kind-$CLUSTER" -n argocd get statefulset argocd-application-controller >/dev/null 2>&1; then
  kubectl --context "kind-$CLUSTER" -n argocd rollout status statefulset/argocd-application-controller --timeout=300s || true
fi

echo "OK: Argo CD installed in namespace 'argocd'."
echo "Initial admin password:"
kubectl --context "kind-$CLUSTER" -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(not yet available)"
echo
