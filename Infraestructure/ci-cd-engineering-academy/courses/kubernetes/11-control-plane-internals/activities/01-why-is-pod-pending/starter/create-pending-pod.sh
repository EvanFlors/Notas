#!/usr/bin/env bash
# Starter for k8s-11-01-why-is-pod-pending.
# Creates (or reuses) a kind cluster and applies a Pod with an impossible
# nodeSelector so the kube-scheduler leaves it Pending forever.
#
# Usage:
#   bash starter/create-pending-pod.sh
#   bash starter/create-pending-pod.sh --no-kind   # use the current kubectl context
#
# No `set -o pipefail` on purpose: downstream `grep -q` on piped commands can
# produce SIGPIPE (141) and pipefail would promote that to a hard failure.

set -eu

MODE="${1:-kind}"
CLUSTER="k8s11-pending"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl is not installed." >&2
  exit 1
fi

if [ "$MODE" != "--no-kind" ]; then
  if ! command -v kind >/dev/null 2>&1; then
    echo "SKIP: 'kind' not installed. Install with 'brew install kind' or pass --no-kind to use your current kubectl context." >&2
    exit 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "FAIL: docker is required by kind." >&2
    exit 1
  fi
  if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    echo "Creating kind cluster '$CLUSTER'..."
    kind create cluster --name "$CLUSTER"
  else
    echo "Reusing existing kind cluster '$CLUSTER'."
  fi
  kubectl config use-context "kind-$CLUSTER"
fi

# Delete previous Pod (if the student is re-running the starter).
kubectl delete pod pending-mystery --ignore-not-found >/dev/null 2>&1 || true

# Impossible nodeSelector: no sensible node ever has this label by default.
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: pending-mystery
  labels:
    app: pending-mystery
    scenario: k8s-11-01
spec:
  nodeSelector:
    disktype: unobtanium-xyz
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "50m"
          memory: "32Mi"
YAML

echo
echo "Pod applied. It will stay Pending — that is the bug to investigate."
echo
echo "Try now:"
echo "  kubectl get pod pending-mystery"
echo "  kubectl describe pod pending-mystery | tail -20"
echo "  kubectl events --for pod/pending-mystery"
