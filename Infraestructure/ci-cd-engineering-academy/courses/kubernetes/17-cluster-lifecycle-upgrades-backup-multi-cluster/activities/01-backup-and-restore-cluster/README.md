# k8s-17-01 — Backup y restore de un namespace con Velero + MinIO

## 1. Identificación

- **ID:** `k8s-17-01-backup-and-restore-cluster`
- **Tecnología:** kubernetes
- **Módulo:** `17-cluster-lifecycle-upgrades-backup-multi-cluster`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

Un cluster que "nunca ha sido restaurado" **no tiene backup verificado**. Esta actividad te lleva por el ciclo completo: instalar backend de object storage local (MinIO), instalar Velero, backupear un namespace con datos reales en un PVC, destruir el namespace y restaurar. Todo sobre **kind**, sin cloud, sin credenciales reales.

Al terminar vas a poder justificar frente a tu equipo que un backup **lo ejecutaste y lo probaste**, no "está programado".

## 3. Objetivos

- Instalar MinIO en el cluster como backend S3-compatible de Velero.
- Instalar Velero con `node-agent` (file-system backup).
- Crear un namespace `demo` con un Deployment que escribe un string identificable a un PVC.
- Hacer backup `demo-backup`, verificar `Completed`.
- Borrar el namespace entero.
- Restaurar desde el backup y verificar: Deployment vuelve, PVC vuelve, el string persiste.

## 4. Prerrequisitos

- Conocimiento de PVC, Deployments, namespaces (módulos k8s-05 y k8s-08).
- **Software**: `kind` ≥ 0.20, `kubectl` ≥ 1.28, binario `velero` (`brew install velero` o descargar release de `github.com/vmware-tanzu/velero/releases`), `jq`.
- **Infraestructura**: 4 GB RAM libre, 5 GB disco libre, Docker funcionando.
- **Variables de entorno** (el validador asume estos defaults; puedes sobrescribir):
  - `CLUSTER_NAME=k8s-17-lab`
  - `KUBECONFIG` apuntando al contexto `kind-k8s-17-lab`.
- **Costos**: 0 USD (todo local).

## 5. Instrucciones

Trabaja en `/tmp/k8s-17-lab/`:

```bash
mkdir -p /tmp/k8s-17-lab
cd /tmp/k8s-17-lab
```

### 5.1 Cluster kind

```bash
kind create cluster --name k8s-17-lab
kubectl config use-context kind-k8s-17-lab
kubectl get nodes
```

### 5.2 MinIO como backend

Instala MinIO en el namespace `minio`. Debe exponer un Service `minio` en `minio.minio.svc:9000` con credenciales `minioadmin:minioadmin` (lab-only). Crea un bucket llamado `velero`.

> Pista: usa `mc alias set local http://localhost:9000 minioadmin minioadmin && mc mb -p local/velero` dentro del Pod MinIO.

### 5.3 Velero

Instala Velero en el namespace `velero` con:

- Provider `aws` (habla S3 contra MinIO).
- Plugin `velero/velero-plugin-for-aws:v1.10.0`.
- Bucket `velero`.
- `--use-volume-snapshots=false`.
- `--use-node-agent` + `--default-volumes-to-fs-backup` (para que los PVC se backupeen vía file-system).
- `backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.minio.svc:9000`.
- Credenciales en un archivo `/tmp/k8s-17-lab/velero-credentials` con el perfil `[default]` apuntando a `minioadmin / minioadmin`.

Verifica:

```bash
velero backup-location get   # default   aws   velero   Available
kubectl -n velero rollout status deploy/velero --timeout=180s
kubectl -n velero rollout status daemonset/node-agent --timeout=180s
```

### 5.4 Namespace `demo` con datos

```bash
kubectl create namespace demo
```

Despliega:

- Un `PersistentVolumeClaim` llamado `data` (RWO, 100Mi).
- Un `Deployment` llamado `writer`, 1 réplica, con un contenedor `busybox:1.36` que ejecute al arrancar:
  ```
  sh -c 'echo "RESTORED-OK" > /data/payload.txt; sleep infinity'
  ```
  montando el PVC en `/data`.

Verifica que el archivo exista:

```bash
kubectl -n demo exec deploy/writer -- cat /data/payload.txt
# RESTORED-OK
```

### 5.5 Backup

```bash
velero backup create demo-backup \
    --include-namespaces demo \
    --wait

velero backup describe demo-backup --details | head -30
```

Debe decir `Phase: Completed` y mostrar un `PodVolumeBackup`.

### 5.6 Desastre y restore

```bash
kubectl delete namespace demo
kubectl get ns demo    # Error: not found

velero restore create --from-backup demo-backup --wait

kubectl -n demo rollout status deploy/writer --timeout=180s
kubectl -n demo exec deploy/writer -- cat /data/payload.txt
# RESTORED-OK   ← los datos del PVC también volvieron
```

### 5.7 Validar

```bash
bash /PATH/TO/activity/tests/validate.sh
```

El validador comprueba todo lo anterior.

## 6. Resultado esperado

- Cluster kind `k8s-17-lab` corriendo.
- Namespace `minio` con Deployment `minio` Ready y Service `minio` en el puerto 9000.
- Namespace `velero` con Deployment `velero` Ready, DaemonSet `node-agent` Ready, y `BackupStorageLocation default` en fase `Available`.
- Backup `demo-backup` en fase `Completed`, visible con `velero backup get`.
- Después del delete + restore: namespace `demo` recreado con Deployment `writer` Ready y PVC `data` Bound; el archivo `/data/payload.txt` dentro del Pod contiene exactamente `RESTORED-OK`.

## 7. Criterios de aceptación

| # | Criterio |
|---|----------|
| 1 | `kubectl get ns minio velero demo` retorna los 3 con `Active`. |
| 2 | `velero backup get demo-backup -o json \| jq -r .status.phase` = `Completed`. |
| 3 | `velero restore get` muestra al menos un restore de `demo-backup` en fase `Completed` (o `PartiallyFailed` con razones aceptables documentadas). |
| 4 | Deployment `writer` en `demo` tiene `.status.readyReplicas == 1`. |
| 5 | PVC `data` en `demo` está `Bound`. |
| 6 | El contenido de `/data/payload.txt` en el Pod del Deployment es exactamente `RESTORED-OK` (sin modificaciones post-restore). |

## 8. Validación

```bash
bash tests/validate.sh
```

El script no asume que ejecutes nada antes (idempotente de lectura). Imprime OK/FAIL por cada check y retorna exit code 0 si todo pasó.

## 9. Preguntas de reflexión

1. ¿Por qué `--default-volumes-to-fs-backup` es necesario en este lab y no lo sería con un CSI driver con snapshotter?
2. Si no hubieras ejecutado `--use-node-agent`, ¿qué habría pasado en el restore con el PVC?
3. Describe cómo detectarías que el backup está "aparentemente OK" pero el restore no funciona (sin probarlo).
4. Si MinIO estuviera en el mismo cluster y perdieras el cluster, ¿pierdes también el backup? ¿Cómo mitigas en producción?
5. En EKS/GKE real, ¿cambiarías `node-agent` por CSI snapshots? ¿Por qué?

## 10. Extensiones

- **Programar un Schedule** diario (`velero schedule create daily-demo --schedule="0 1 * * *" --include-namespaces=demo`).
- **Restore a otro namespace** usando `--namespace-mappings demo:demo-copy`.
- **Backup hooks**: añade un hook `pre` que ejecute `sync` en el Pod antes del backup para flushear buffers.
- **Validar en producción**: diseña un cronjob interno que *restaure* el backup diario en un namespace scratch y haga `smoke test`; alerta si falla.

## 11. Limpieza

```bash
kind delete cluster --name k8s-17-lab
rm -rf /tmp/k8s-17-lab
```

Esto deja la máquina como estaba antes del lab. Un script `cleanup.sh` está en `solution/`.
