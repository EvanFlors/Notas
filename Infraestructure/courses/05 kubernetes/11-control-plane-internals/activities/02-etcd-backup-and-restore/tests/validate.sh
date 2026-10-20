#!/usr/bin/env bash
# Validate: student took and inspected an etcd snapshot.
#
# No `set -o pipefail` on purpose: downstream `grep -q` with pipes can
# produce SIGPIPE (141) that pipefail would mark as failure.

set -eu

OUT="/tmp/etcd-backup"
fail=0

echo "== Validating k8s-11-02-etcd-backup-and-restore =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no reachable Kubernetes cluster."
  exit 0
fi

if ! kubectl -n kube-system get pods -l component=etcd 2>/dev/null | grep -q etcd-; then
  echo "SKIP: no etcd static Pod found (expected in kubeadm/kind; absent in EKS/GKE/AKS)."
  exit 0
fi

# Snapshot file exists and is non-trivial in size.
if [ -f "$OUT/snapshot.db" ]; then
  echo "  OK   $OUT/snapshot.db present"
  size=$(wc -c < "$OUT/snapshot.db")
  if [ "$size" -gt 102400 ]; then
    echo "  OK   snapshot size = $size bytes (> 100 KiB)"
  else
    echo "  FAIL snapshot size = $size bytes (expected > 100 KiB; snapshot likely empty or truncated)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $OUT/snapshot.db missing"
  fail=$((fail+1))
fi

# Snapshot status captured and mentions revision + total keys.
if [ -f "$OUT/status.txt" ]; then
  echo "  OK   $OUT/status.txt present"
  if grep -qiE "REVISION|TOTAL KEYS|TOTAL SIZE" "$OUT/status.txt"; then
    echo "       - status looks like etcdctl snapshot status output"
  else
    echo "  FAIL $OUT/status.txt does not look like snapshot status output"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $OUT/status.txt missing (run 'etcdctl snapshot status --write-out=table')"
  fail=$((fail+1))
fi

# Key sample captured and includes /registry/ keys.
if [ -f "$OUT/keys-sample.txt" ]; then
  echo "  OK   $OUT/keys-sample.txt present"
  if grep -q "^/registry/" "$OUT/keys-sample.txt"; then
    echo "       - contains /registry/* keys"
  else
    echo "  FAIL $OUT/keys-sample.txt does not contain any /registry/* key"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $OUT/keys-sample.txt missing"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: k8s-11-02 completed."
exit 0
