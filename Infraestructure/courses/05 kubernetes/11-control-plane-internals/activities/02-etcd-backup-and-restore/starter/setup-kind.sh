#!/usr/bin/env bash
# Starter for k8s-11-02-etcd-backup-and-restore.
# Ensures a kind cluster exists and the etcd static Pod is Running.
#
# No `set -o pipefail` on purpose: grep -q + pipes can produce SIGPIPE (141).

set -eu

CLUSTER="k8s11-etcd"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl not installed." >&2
  exit 1
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "SKIP: 'kind' not installed. Install with 'brew install kind'." >&2
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

echo "Waiting for the etcd static Pod to be Ready..."
kubectl -n kube-system wait --for=condition=Ready pod -l component=etcd --timeout=120s

ETCD_POD=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')
echo
echo "etcd pod: $ETCD_POD"
echo "Next: follow README section 5.3 to take the snapshot."
