#!/usr/bin/env bash
# Demo runner for example 01: Velero backup/restore on kind + MinIO.
#
# This is a reference script — read the README step by step first.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because some
# checks pipe into `grep -q`, and grep closing the pipe early produces
# SIGPIPE on the upstream which pipefail would misreport as failure.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-k8s-17-lab}"
MINIO_NS="${MINIO_NS:-minio}"
VELERO_NS="${VELERO_NS:-velero}"
BUCKET="${BUCKET:-velero}"
WORKDIR="${WORKDIR:-/tmp/k8s-17-example-01}"

mkdir -p "$WORKDIR"

echo "[1] kind cluster"
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME"
fi
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

echo "[2] MinIO backend"
kubectl get ns "$MINIO_NS" >/dev/null 2>&1 || kubectl create namespace "$MINIO_NS"
kubectl -n "$MINIO_NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: minio, labels: {app: minio}}
spec:
  replicas: 1
  selector: {matchLabels: {app: minio}}
  template:
    metadata: {labels: {app: minio}}
    spec:
      containers:
        - name: minio
          image: quay.io/minio/minio:latest
          args: ["server", "/data", "--console-address", ":9001"]
          env:
            - {name: MINIO_ROOT_USER, value: minioadmin}
            - {name: MINIO_ROOT_PASSWORD, value: minioadmin}
          ports:
            - {containerPort: 9000, name: s3}
            - {containerPort: 9001, name: console}
          volumeMounts: [{name: data, mountPath: /data}]
      volumes:
        - {name: data, emptyDir: {}}
---
apiVersion: v1
kind: Service
metadata: {name: minio}
spec:
  selector: {app: minio}
  ports:
    - {name: s3, port: 9000, targetPort: 9000}
    - {name: console, port: 9001, targetPort: 9001}
EOF
kubectl -n "$MINIO_NS" rollout status deploy/minio --timeout=180s

echo "[3] bucket in MinIO"
for i in 1 2 3 4 5; do
  if kubectl -n "$MINIO_NS" exec deploy/minio -- sh -c \
      "mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null && \
       (mc mb -p local/$BUCKET >/dev/null 2>&1 || true) && \
       mc ls local/$BUCKET >/dev/null"; then
    break
  fi
  sleep 3
done

echo "[4] Velero install"
cat > "$WORKDIR/velero-credentials" <<'EOF'
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=minioadmin
EOF

if ! kubectl get ns "$VELERO_NS" >/dev/null 2>&1; then
  velero install \
      --provider aws \
      --plugins velero/velero-plugin-for-aws:v1.10.0 \
      --bucket "$BUCKET" \
      --secret-file "$WORKDIR/velero-credentials" \
      --use-volume-snapshots=false \
      --use-node-agent \
      --default-volumes-to-fs-backup \
      --backup-location-config \
          "region=minio,s3ForcePathStyle=true,s3Url=http://minio.$MINIO_NS.svc:9000" \
      --namespace "$VELERO_NS"
fi
kubectl -n "$VELERO_NS" rollout status deploy/velero --timeout=240s
kubectl -n "$VELERO_NS" rollout status daemonset/node-agent --timeout=240s

echo "[5] demo workload with payload"
kubectl get ns demo >/dev/null 2>&1 || kubectl create namespace demo
kubectl -n demo apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: data}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 100Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: writer}
spec:
  replicas: 1
  selector: {matchLabels: {app: writer}}
  template:
    metadata: {labels: {app: writer}}
    spec:
      containers:
        - name: shell
          image: busybox:1.36
          command: ["sh", "-c"]
          args:
            - 'echo "important payload v1" > /data/payload.txt; sleep infinity'
          volumeMounts: [{name: data, mountPath: /data}]
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: data}
EOF
kubectl -n demo rollout status deploy/writer --timeout=180s
kubectl -n demo exec deploy/writer -- cat /data/payload.txt

echo "[6] backup, delete, restore"
velero backup create demo-1 --include-namespaces demo --wait
kubectl delete namespace demo --wait=true
velero restore create "restore-$(date +%s)" --from-backup demo-1 --wait
kubectl -n demo rollout status deploy/writer --timeout=240s

echo
echo "[7] payload after restore:"
kubectl -n demo exec deploy/writer -- cat /data/payload.txt

echo
echo "Cleanup when done: kind delete cluster --name $CLUSTER_NAME && rm -rf $WORKDIR"
