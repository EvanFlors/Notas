# Actividad 02 — Backup (y notas de restore) de `etcd` en `kind`

## 1. Identificación

- **ID:** `k8s-11-02-etcd-backup-and-restore`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-11-control-plane-internals`
- **Dificultad:** advanced
- **Duración estimada:** 40–60 min
- **Tipo:** guided-lab

## 2. Contexto

`etcd` es la fuente de verdad del cluster. Un snapshot `.db` consistente es la última línea de defensa ante un desastre del control plane. En producción se automatiza con **Velero** (módulo `k8s-17`); aquí vas a hacerlo a mano para **ver qué hay dentro** y entender por qué el restore no es trivial en `kind`.

## 3. Objetivos

Al terminar deberías poder:

- Localizar el Pod estático de `etcd` en `kube-system` y los certs TLS que usa.
- Tomar un snapshot con `etcdctl snapshot save` ejecutado dentro del Pod.
- Copiarlo fuera del cluster con `kubectl cp` y verificar su tamaño.
- Inspeccionar el snapshot con `etcdctl snapshot status` y listar keys bajo `/registry/`.
- Explicar por qué el restore completo requiere parar el kubelet y mover `/var/lib/etcd/`, y por qué eso en `kind` es frágil.

## 4. Prerrequisitos

### Conocimientos

- `k8s-01` (arquitectura) y `k8s-02` (CLI).
- Haber leído `theory/lesson.md` secciones 2, 3 y 11.

### Software

- `kubectl` ≥ 1.28.
- `kind` + `docker` para el cluster local.
- `jq` opcional.

### Costos

Ninguno.

## 5. Instrucciones

### 5.1 Preparar el cluster

```bash
bash starter/setup-kind.sh
# Crea (o reusa) el cluster kind "k8s11-etcd" y verifica que el Pod de etcd está Running.
```

### 5.2 Localizar el Pod de etcd

```bash
kubectl -n kube-system get pods -l component=etcd
# NAME                             READY   STATUS    RESTARTS   AGE
# etcd-k8s11-etcd-control-plane    1/1     Running   0          2m

ETCD_POD=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')
echo "etcd pod: $ETCD_POD"
```

El manifiesto del Pod estático vive en `/etc/kubernetes/manifests/etcd.yaml` **dentro del contenedor del nodo del control plane**, montado por el kubelet. Puedes verlo con:

```bash
docker exec k8s11-etcd-control-plane cat /etc/kubernetes/manifests/etcd.yaml | head -40
```

Observa los flags: `--data-dir=/var/lib/etcd`, `--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt`, etc.

### 5.3 Snapshot

```bash
mkdir -p /tmp/etcd-backup

kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /tmp/snapshot.db
'

kubectl -n kube-system cp "$ETCD_POD:/tmp/snapshot.db" /tmp/etcd-backup/snapshot.db
ls -lh /tmp/etcd-backup/snapshot.db
```

El archivo debe pesar al menos ~1 MiB (incluye el estado completo del cluster `kind` recién creado).

### 5.4 Verificar el snapshot

```bash
# Status (hash, revision, keys, size).
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl snapshot status /tmp/snapshot.db --write-out=table
' | tee /tmp/etcd-backup/status.txt

# Lista parcial de keys top-level de /registry/.
kubectl -n kube-system exec "$ETCD_POD" -- sh -c '
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/ --prefix --keys-only
' | head -40 | tee /tmp/etcd-backup/keys-sample.txt
```

### 5.5 Restore — qué harías (y por qué aquí no lo hacemos end-to-end)

En un cluster `kubeadm` self-hosted real:

```bash
# EN EL NODO del control plane:
systemctl stop kubelet
mv /var/lib/etcd /var/lib/etcd.bak
ETCDCTL_API=3 etcdctl snapshot restore /tmp/snapshot.db \
    --data-dir=/var/lib/etcd \
    --name=<etcd-member-name> \
    --initial-advertise-peer-urls=https://<node-ip>:2380 \
    --initial-cluster=<etcd-member-name>=https://<node-ip>:2380
systemctl start kubelet
# El kubelet re-arranca el static Pod de etcd apuntando al nuevo /var/lib/etcd.
```

En `kind` el "nodo" es un contenedor Docker; `/var/lib/etcd` vive dentro de ese contenedor. Puedes hacerlo con `docker exec` + parar/arrancar containerd, pero el proceso es sensible: si lo haces mal, el cluster `kind` queda inservible y toca `kind delete cluster`. Para producción, usa **Velero** (cubierto en `k8s-17`), que:

- Serializa cada recurso de la API (más portable que un `.db` binario).
- Integra snapshots de volúmenes CSI para datos de aplicaciones.
- Permite restore selectivo por namespace o label.

Dejas documentado en tus notas esta diferencia; el validator no pide ejecutar el restore.

### 5.6 Validar

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- `/tmp/etcd-backup/snapshot.db` existe con tamaño > 1 MiB.
- `/tmp/etcd-backup/status.txt` incluye `TOTAL KEYS` y una `REVISION` > 0.
- `/tmp/etcd-backup/keys-sample.txt` incluye claves bajo `/registry/` (p. ej. `/registry/namespaces/default`, `/registry/pods/...`).
- Validator en `OK`.

## 7. Criterios de aceptación

- [ ] Snapshot copiado fuera del Pod y de tamaño razonable.
- [ ] `snapshot status` muestra hash, revision, keys y size.
- [ ] Al menos una clave `/registry/...` capturada en `keys-sample.txt`.

## 8. Validación

```bash
bash tests/validate.sh
```

En entornos sin cluster accesible o sin el Pod de etcd (p. ej. EKS), el validator imprime `SKIP` y exit 0.

## 9. Preguntas de reflexión

1. ¿Por qué `etcdctl snapshot save` genera un archivo consistente aunque haya escrituras en vuelo? (pista: lee sobre `MVCC` y snapshotting de etcd).
2. ¿Qué pasa con los Secrets que estaban cifrados en reposo (`--encryption-provider-config`) al restaurar en otro cluster? ¿Puedes leerlos sin la misma clave?
3. ¿Cuál es la **ventana de datos** que pierdes entre dos snapshots? ¿Cómo acortarías esa ventana (hint: `--wal-dir` separado + backups de WAL)?
4. ¿Por qué el apiserver es la única pieza que escribe en etcd y no, por ejemplo, el `kube-controller-manager` directamente?
5. Si tu snapshot pesa 2 GiB (`--quota-backend-bytes` default) y tu red hacia S3 es 100 Mbps, ¿cuánto tarda subirlo? ¿Qué estrategia usarías para no quedarte sin cuota (`etcdctl compact`, `defrag` programado)?

## 10. Extensiones (opcional)

- **E1** — Programa el snapshot con un `CronJob` que corra `etcdctl` en un Pod con los certs montados (requiere un ServiceAccount + Role con acceso a los paths del host, o un sidecar DaemonSet).
- **E2** — Habilita el audit log en `kind` editando el static Pod del apiserver (`docker exec` al nodo, editar `/etc/kubernetes/manifests/kube-apiserver.yaml`). Observa cómo se reinicia el apiserver y revisa `/var/log/kubernetes/audit.log`.
- **E3** — Instala Velero contra MinIO local y compara el output: Velero produce un tar con los YAML, no un `.db` binario.

## 11. Limpieza

```bash
rm -rf /tmp/etcd-backup
# opcional: kind delete cluster --name k8s11-etcd
```
