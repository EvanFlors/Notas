# Ejemplo 02 — `etcdctl snapshot save` y restore (demo)

## Concepto que demuestra

Que `etcd` es un KV store accesible: puedes abrir un shell en su Pod (es un **static Pod** del control plane), tomar un snapshot consistente a un punto en el tiempo, inspeccionar su contenido y, en teoría, restaurarlo. En `kind` el restore completo requiere reconstruir el nodo, así que aquí la **demo** termina en snapshot + inspección.

## Plataforma

Cluster `kind` (o `kubeadm` self-hosted). En EKS/GKE no funciona: el etcd es gestionado y no expuesto.

## Prerrequisitos

- `kind` + `kubectl`.
- `jq` (opcional).

## Setup

```bash
kind create cluster --name k8s11-etcd 2>/dev/null || true
kubectl config use-context kind-k8s11-etcd

# Localiza el Pod estático de etcd
kubectl -n kube-system get pods -l component=etcd
# NAME                             READY   STATUS
# etcd-k8s11-etcd-control-plane    1/1     Running
```

## Ejecución

### 1. Snapshot via `kubectl exec`

```bash
ETCD_POD=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')
echo "etcd pod: $ETCD_POD"

mkdir -p /tmp/etcd-backup

# etcdctl habla con el peer local sobre TLS mutual.
# Los certs del control-plane están montados en /etc/kubernetes/pki/etcd/.
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /tmp/snapshot.db
'

# Copiar el snapshot fuera del Pod
kubectl -n kube-system cp "$ETCD_POD:/tmp/snapshot.db" /tmp/etcd-backup/snapshot.db
ls -lh /tmp/etcd-backup/snapshot.db
```

### 2. Inspeccionar el snapshot

```bash
# Opción A: dentro del Pod (etcdctl ya está)
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl snapshot status /tmp/snapshot.db --write-out=table
'
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | abcd1234 |     NNNN |        NNN |   X MB     |
# +----------+----------+------------+------------+
```

### 3. Listar keys top-level en etcd

Las claves de Kubernetes viven todas bajo `/registry/`:

```bash
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/ --prefix --keys-only
' | head -30
# /registry/apiregistration.k8s.io/apiservices/...
# /registry/configmaps/kube-system/...
# /registry/leases/kube-system/kube-controller-manager
# /registry/namespaces/default
# /registry/pods/kube-system/coredns-...
# /registry/secrets/default/default-token-...
```

Si quieres ver el **valor** de una key:

```bash
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/namespaces/default
'
# El valor es protobuf; verás bytes binarios con el nombre "default" legible.
```

### 4. Restore — por qué aquí paramos

En un cluster self-hosted con `kubeadm`:

```bash
# EN EL NODO del control plane (no en el Pod):
systemctl stop kubelet
mv /var/lib/etcd /var/lib/etcd.bak
ETCDCTL_API=3 etcdctl snapshot restore /tmp/snapshot.db \
    --data-dir=/var/lib/etcd \
    --name=<etcd-member-name> \
    --initial-advertise-peer-urls=https://<node-ip>:2380 \
    --initial-cluster=<etcd-member-name>=https://<node-ip>:2380
systemctl start kubelet
```

En `kind` el nodo del control plane es un contenedor Docker inmutable: el kubelet corre dentro, etcd corre como static Pod, y "parar el kubelet y restaurar `/var/lib/etcd`" requiere entrar al contenedor con `docker exec`, parar containerd, mover el directorio, y arrancar de nuevo. Es viable pero frágil; para fines didácticos, basta con haber tomado y verificado el snapshot. La actividad 02 del módulo `k8s-17` cubre backup/restore operativo con **Velero** (que es la ruta real en producción).

## Limpieza

```bash
rm -rf /tmp/etcd-backup
# opcional: kind delete cluster --name k8s11-etcd
```

## Lo que deberías notar

- etcd se habla con **TLS mutual**; los certs viven en `/etc/kubernetes/pki/etcd/`.
- Todas las claves de Kubernetes van bajo `/registry/<group>/<resource>/<namespace>/<name>`.
- Los valores son **protobuf** (no JSON): optimización de espacio y velocidad.
- Un snapshot es un **archivo único**: se puede copiar fuera del cluster trivialmente.
- Restore en `kind` ≠ restore en producción. Para producción real usa **Velero** (recursos + volúmenes).
