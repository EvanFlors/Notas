#!/usr/bin/env bash
# Install Velero + MinIO (in-cluster S3-compatible storage) for the example.
# NOT production-grade: single MinIO replica, no auth hardening, no TLS.
set -euo pipefail

WORK="${WORK:-/tmp/argo-11-ex03}"
mkdir -p "$WORK"
cd "$WORK"

if ! command -v velero >/dev/null 2>&1; then
  echo "SKIP: velero CLI not installed. See https://velero.io/docs/latest/basic-install/" >&2
  exit 0
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed" >&2
  exit 0
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: no active kube context" >&2
  exit 0
fi

echo "== Deploying MinIO in namespace 'velero' =="
kubectl create ns velero --dry-run=client -o yaml | kubectl apply -f -

cat > minio.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: minio, namespace: velero, labels: { app: minio } }
spec:
  replicas: 1
  selector: { matchLabels: { app: minio } }
  template:
    metadata: { labels: { app: minio } }
    spec:
      containers:
        - name: minio
          image: minio/minio:RELEASE.2024-05-10T01-41-38Z
          args: ["server", "/data", "--console-address", ":9001"]
          env:
            - { name: MINIO_ROOT_USER,     value: "minio" }
            - { name: MINIO_ROOT_PASSWORD, value: "minio123" }
          ports: [{ containerPort: 9000 }, { containerPort: 9001 }]
          volumeMounts: [{ name: data, mountPath: /data }]
      volumes: [{ name: data, emptyDir: {} }]
---
apiVersion: v1
kind: Service
metadata: { name: minio, namespace: velero }
spec:
  selector: { app: minio }
  ports:
    - { name: s3,      port: 9000, targetPort: 9000 }
    - { name: console, port: 9001, targetPort: 9001 }
EOF
kubectl apply -f minio.yaml
kubectl -n velero rollout status deploy/minio --timeout=120s

echo "== Creating bucket 'velero' in MinIO =="
kubectl -n velero run mc --rm -i --restart=Never --image=minio/mc:RELEASE.2024-05-09T17-04-24Z --command -- \
  sh -c "mc alias set m http://minio:9000 minio minio123 && mc mb -p m/velero || true"

echo "== Writing MinIO creds file (local) =="
cat > credentials-velero <<'EOF'
[default]
aws_access_key_id=minio
aws_secret_access_key=minio123
EOF

echo "== Installing Velero =="
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.velero.svc:9000 \
  --wait

echo "== Verifying BackupStorageLocation =="
for i in 1 2 3 4 5 6; do
  phase="$(kubectl -n velero get backupstoragelocation default -o jsonpath='{.status.phase}' 2>/dev/null || echo '')"
  echo "  attempt $i: phase=$phase"
  [ "$phase" = "Available" ] && break
  sleep 5
done

echo "OK: Velero + MinIO ready."
