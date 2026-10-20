#!/usr/bin/env bash
# Reference solution for k8s-11-02-etcd-backup-and-restore.
# Takes a snapshot of etcd in a kind cluster, inspects it, and writes the
# evidence files the validator looks for.
#
# No `set -o pipefail` on purpose.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$HERE/.." && pwd)"
OUT="/tmp/etcd-backup"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed." >&2
  exit 0
fi

# 1. Make sure the cluster exists.
bash "$ACT_DIR/starter/setup-kind.sh"

ETCD_POD=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')
if [ -z "$ETCD_POD" ]; then
  echo "SKIP: no etcd static Pod found." >&2
  exit 0
fi

mkdir -p "$OUT"

# 2. Snapshot inside the Pod.
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /tmp/snapshot.db
'

# 3. Copy out.
kubectl -n kube-system cp "$ETCD_POD:/tmp/snapshot.db" "$OUT/snapshot.db"
ls -lh "$OUT/snapshot.db"

# 4. Inspect: status table.
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl snapshot status /tmp/snapshot.db --write-out=table
' > "$OUT/status.txt"
cat "$OUT/status.txt"

# 5. Key sample from the live store.
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/ --prefix --keys-only
' | head -40 > "$OUT/keys-sample.txt"
echo "First few /registry/ keys:"
head -5 "$OUT/keys-sample.txt"

echo
echo "Evidence in $OUT/:"
ls -la "$OUT"
echo
echo "Run: bash tests/validate.sh"
