# Ejemplo 01 — Velero backup/restore en kind con MinIO local

> Demostración completa de backup y restore de un namespace sobre un cluster **kind**, usando **MinIO** como object storage S3-compatible (todo local, cero cloud).

## Qué demuestra

- Instalación de MinIO en el cluster como backend de Velero.
- Instalación de Velero con el plugin AWS (habla S3 → MinIO) y `node-agent` (file-system backup, independiente de CSI).
- Backup de un namespace con un workload desplegado y datos escritos a un volumen.
- Borrado del namespace completo.
- Restore desde el backup.
- Verificación de que los datos reaparecen.

No usa snapshots CSI porque kind no provee un CSI snapshotter completo por default — usamos el `node-agent` (file-system backup) que es independiente del driver.

## Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, `helm` ≥ 3.12.
- Binario `velero` (`brew install velero` o descarga del release).
- 4 GB RAM libre, 5 GB disco libre.

## Variables usadas

```bash
export CLUSTER_NAME=k8s-17-lab
export MINIO_NS=minio
export VELERO_NS=velero
export BUCKET=velero
```

Credenciales MinIO de desarrollo (NO usar fuera de este lab):
`minioadmin:minioadmin`.

## Pasos

### 1. Crear el cluster kind

```bash
kind create cluster --name "$CLUSTER_NAME"
kubectl config use-context "kind-$CLUSTER_NAME"
kubectl get nodes
```

### 2. Instalar MinIO como backend

```bash
kubectl create namespace "$MINIO_NS"

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

kubectl -n "$MINIO_NS" rollout status deploy/minio --timeout=120s
```

Crear el bucket `velero` dentro de MinIO:

```bash
kubectl -n "$MINIO_NS" exec deploy/minio -- \
    mc alias set local http://localhost:9000 minioadmin minioadmin
kubectl -n "$MINIO_NS" exec deploy/minio -- \
    mc mb -p local/velero
```

### 3. Credenciales para Velero

```bash
cat > /tmp/velero-credentials <<'EOF'
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=minioadmin
EOF
```

### 4. Instalar Velero

```bash
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.10.0 \
    --bucket "$BUCKET" \
    --secret-file /tmp/velero-credentials \
    --use-volume-snapshots=false \
    --use-node-agent \
    --default-volumes-to-fs-backup \
    --backup-location-config \
        region=minio,s3ForcePathStyle=true,s3Url=http://minio.minio.svc:9000 \
    --namespace "$VELERO_NS"

kubectl -n "$VELERO_NS" rollout status deploy/velero --timeout=180s
kubectl -n "$VELERO_NS" rollout status daemonset/node-agent --timeout=180s

velero backup-location get
# default   aws   velero   Available
```

### 5. Workload de prueba con datos

```bash
kubectl create namespace demo

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
          volumeMounts:
            - {name: data, mountPath: /data}
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: data}
EOF

kubectl -n demo rollout status deploy/writer --timeout=120s
kubectl -n demo exec deploy/writer -- cat /data/payload.txt
# important payload v1
```

### 6. Backup

```bash
velero backup create demo-1 --include-namespaces demo --wait
velero backup describe demo-1 --details | head -40
```

Esperable: `Phase: Completed`, `Items backed up`, y un `PodVolumeBackup` por el PVC.

### 7. Simular desastre y restaurar

```bash
kubectl delete namespace demo
kubectl get ns demo
# Error from server (NotFound)

velero restore create --from-backup demo-1 --wait
kubectl -n demo rollout status deploy/writer --timeout=180s
kubectl -n demo exec deploy/writer -- cat /data/payload.txt
# important payload v1   ← los datos del PVC también volvieron
```

### 8. Limpieza

```bash
kind delete cluster --name "$CLUSTER_NAME"
rm -f /tmp/velero-credentials
```

## Qué hay que mirar

- `velero backup describe demo-1 --details` lista cada recurso backupeado y cada `PodVolumeBackup`.
- `velero restore describe` muestra warnings esperables: `ClusterRoleBinding` ya existentes (ignorados), namespaces del sistema skipped.
- Si no ves `PodVolumeBackup`, probablemente olvidaste `--default-volumes-to-fs-backup` o `--use-node-agent`.

## Script de ejecución

Ver `files/run-demo.sh` — ejecuta los pasos 1–8 en orden idempotente. Pensado para seguir leyendo *paso a paso*; no para correrlo entero sin mirar.
