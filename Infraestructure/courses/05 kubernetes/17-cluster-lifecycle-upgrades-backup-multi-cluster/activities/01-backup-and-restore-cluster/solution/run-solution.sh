#!/usr/bin/env bash
# Solution runner for k8s-17-01-backup-and-restore-cluster.
# Idempotent: safe to re-run. Leaves artifacts for the validator.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because several
# checks pipe into `grep -q`, and grep closing the pipe early produces
# SIGPIPE (141) on the upstream producer, which pipefail would misreport.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-k8s-17-lab}"
MINIO_NS="${MINIO_NS:-minio}"
VELERO_NS="${VELERO_NS:-velero}"
DEMO_NS="${DEMO_NS:-demo}"
BUCKET="${BUCKET:-velero}"
WORKDIR="${WORKDIR:-/tmp/k8s-17-lab}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "== [1/7] Ensuring kind cluster '$CLUSTER_NAME' =="
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME"
fi
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

echo "== [2/7] Installing MinIO backend =="
kubectl get ns "$MINIO_NS" >/dev/null 2>&1 || kubectl create namespace "$MINIO_NS"
kubectl -n "$MINIO_NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  labels: {app: minio}
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
          volumeMounts:
            - {name: data, mountPath: /data}
          readinessProbe:
            httpGet: {path: /minio/health/ready, port: 9000}
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata: {name: minio, labels: {app: minio}}
spec:
  selector: {app: minio}
  ports:
    - {name: s3, port: 9000, targetPort: 9000}
    - {name: console, port: 9001, targetPort: 9001}
EOF
kubectl -n "$MINIO_NS" rollout status deploy/minio --timeout=180s

echo "== [3/7] Creating bucket '$BUCKET' in MinIO =="
# retry — Deployment may be Ready seconds before mc works
for i in 1 2 3 4 5; do
  if kubectl -n "$MINIO_NS" exec deploy/minio -- \
       sh -c "mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null && \
              mc mb -p local/$BUCKET >/dev/null 2>&1 || true && \
              mc ls local/$BUCKET >/dev/null"; then
    break
  fi
  sleep 3
done

echo "== [4/7] Writing Velero credentials to $WORKDIR/velero-credentials =="
cat > "$WORKDIR/velero-credentials" <<'EOF'
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=minioadmin
EOF

echo "== [5/7] Installing Velero (if not present) =="
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

echo "== [6/7] Demo workload with payload =="
kubectl get ns "$DEMO_NS" >/dev/null 2>&1 || kubectl create namespace "$DEMO_NS"
kubectl -n "$DEMO_NS" apply -f - <<'EOF'
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
            - 'echo "RESTORED-OK" > /data/payload.txt; sleep infinity'
          volumeMounts:
            - {name: data, mountPath: /data}
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: data}
EOF
kubectl -n "$DEMO_NS" rollout status deploy/writer --timeout=180s

echo "== [7/7] Backup, delete, restore =="
if ! velero backup get demo-backup 2>/dev/null | grep -q Completed; then
  velero backup create demo-backup --include-namespaces "$DEMO_NS" --wait
fi

kubectl delete namespace "$DEMO_NS" --wait=true

velero restore create "restore-$(date +%s)" --from-backup demo-backup --wait
kubectl -n "$DEMO_NS" rollout status deploy/writer --timeout=240s

echo
echo "== Payload after restore =="
kubectl -n "$DEMO_NS" exec deploy/writer -- cat /data/payload.txt
echo
echo "Done. Run tests/validate.sh to validate."
