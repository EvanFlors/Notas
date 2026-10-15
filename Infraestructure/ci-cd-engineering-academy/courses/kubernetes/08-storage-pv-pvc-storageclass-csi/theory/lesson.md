# k8s-08 — Teoría: almacenamiento persistente en Kubernetes

> 12 secciones. Prosa en español, código en inglés.

## 1. Por qué el storage es un problema aparte

El filesystem *de un contenedor* es efímero. Al borrarlo, el `upperdir` del overlay se descarta y los datos escritos en el rootfs desaparecen. Para cargas sin estado (web APIs, workers *stateless*) eso es ideal: los Pods son ganado, no mascotas, y se reemplazan sin ceremonia. Para una base de datos, un buffer de eventos, un modelo de ML, un repositorio de artifacts o cualquier estado que deba *sobrevivir* a la vida de un Pod, es inaceptable.

Kubernetes separa, por diseño, la **declaración de necesidad de almacenamiento** (lo que la aplicación pide) de la **implementación del almacenamiento** (lo que el proveedor de infraestructura entrega). Esa separación es la razón por la cual una misma aplicación corre sin cambios en kind con `local-path`, en EKS con EBS y en bare-metal con Longhorn.

Si en el curso anterior (`k8s-06`) usamos un `StatefulSet` con `volumeClaimTemplates`, aquí abrimos la caja negra: cómo se materializa ese PVC, qué hace la `StorageClass` y qué negocia el CSI driver debajo.

## 2. Modelo mental: PVC es un pedido, PV es una oferta

Hay cuatro actores:

- **PersistentVolumeClaim (PVC)** — namespace-scoped. Lo escribe el autor de la aplicación. Dice: "necesito 10 GiB, `ReadWriteOnce`, de la StorageClass `fast-ssd`". Es un **pedido tipado**.
- **StorageClass** — cluster-scoped. La define el administrador. Dice: "yo representa esta familia de almacenamiento; estoy respaldada por este CSI driver con estos parámetros, con este `volumeBindingMode`, este `reclaimPolicy` y permito o no expansión".
- **PersistentVolume (PV)** — cluster-scoped. Representa un volumen *real*. Puede existir **estáticamente** (lo creó alguien a mano apuntando a un disco preexistente) o **dinámicamente** (lo creó el CSI driver en respuesta a un PVC).
- **CSI driver** — el componente que habla con la API del backend (EBS, GCE PD, Azure Disk, Ceph, local-path, EFS, NFS, …) y materializa el volumen.

El ciclo normal es:

```
Usuario crea PVC
      │
      ▼
PVC referencia una StorageClass (o la default del cluster)
      │
      ▼
Si volumeBindingMode=Immediate: el provisioner CSI crea el PV ya
Si volumeBindingMode=WaitForFirstConsumer: espera a que un Pod use el PVC
      │
      ▼
PV queda Bound al PVC
      │
      ▼
Un Pod monta el PVC vía volumes[] + volumeMounts[]
      │
      ▼
kubelet pide al CSI driver attach + mount
      │
      ▼
El Pod ve el filesystem en el path indicado
```

**No** se escriben PVs a mano salvo que se adopte un volumen estático preexistente (migración, importación). Lo normal es: `PVC + StorageClass → el PV se crea dinámicamente`.

## 3. Access modes y el malentendido más común

Los access modes son **contrato entre PV y PVC**, no una propiedad mágica del volumen. Los cuatro:

- **ReadWriteOnce (RWO)** — el volumen puede montarse para lectura-escritura por *un solo nodo* a la vez. Múltiples Pods en *ese mismo nodo* pueden escribirlo. Es lo que entrega EBS, GCE PD, Azure Disk y cualquier block storage.
- **ReadOnlyMany (ROX)** — múltiples nodos pueden montarlo pero solo-lectura.
- **ReadWriteMany (RWX)** — múltiples nodos pueden montarlo en lectura-escritura simultáneamente. Requiere un filesystem compartido (NFS, EFS, Filestore, CephFS, GlusterFS).
- **ReadWriteOncePod (RWOP)** — introducido relativamente reciente. El volumen solo puede ser montado por *un único Pod* (no un nodo). Resuelve ambigüedades del RWO cuando dos Pods del mismo nodo escriben el mismo volumen y uno rompe al otro.

Error típico: pedir **RWX** porque "quiero más réplicas". No. Un Deployment stateless no necesita RWX: cada réplica es independiente y no comparte estado. Lo que *sí* necesita RWX es un escenario como un CMS legacy que escribe uploads al disco y debe escalar horizontalmente leyendo esos uploads desde cualquier réplica. La solución correcta en green-field es object storage (S3/GCS), no RWX. RWX en Kubernetes es correcto en nichos: notebooks compartidos, builds de CI con cache compartido, pipelines de datos, etc.

## 4. StorageClass al detalle

Una `StorageClass` típica:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Campos clave:

- **`provisioner`** — nombre del CSI driver que la maneja.
- **`parameters`** — pasan tal cual al CSI; cambian según el driver (tipo de disco, IOPS, throughput, filesystem, encryption, replicación, etc.).
- **`reclaimPolicy`** — qué hacer cuando el PVC se borra:
  - `Delete`: borra el PV y, con él, el volumen *subyacente* en el cloud. Default común y agresivo.
  - `Retain`: conserva el PV en estado `Released`; nadie más puede ligarse a él sin intervención manual. Da red de seguridad en producción.
- **`volumeBindingMode`** — ver sección 5.
- **`allowVolumeExpansion`** — habilita expansión online: luego de crear el PVC con 10 GiB, puedes editar `spec.resources.requests.storage` a 20 GiB y el CSI driver expande el volumen y el filesystem sin reinicio.

Una StorageClass puede marcarse como **default** del cluster con la anotación `storageclass.kubernetes.io/is-default-class: "true"`. En kind, `local-path` es la default. En EKS, no hay default *hasta que la configures explícitamente* (muchos clusters en producción traen `gp2` default por accidente histórico; conviene revisarlo).

## 5. `volumeBindingMode`: el detalle que rompe multi-AZ

Hay dos modos:

- **`Immediate`** — en cuanto se crea el PVC, el CSI driver crea el PV. La elección de AZ es *tomada por el provisioner* (típicamente la primera AZ listada o round-robin, dependiendo del driver). Resultado: el PV existe en, p. ej., `us-east-1a`.
  - Problema: el `kube-scheduler` todavía no ha asignado el Pod. Cuando asigne el Pod, debe hacerlo a un nodo *en la misma AZ que el PV* (porque EBS/PD son zonales: un disco en `us-east-1a` no se monta desde `us-east-1b`). Si el Pod tiene `nodeSelector`, `nodeAffinity`, `taints/tolerations`, `topologySpreadConstraints` que lo *obligan* a otra AZ, queda `Pending` para siempre con el mensaje `node(s) had volume node affinity conflict`.
- **`WaitForFirstConsumer`** — el PVC queda `Pending` hasta que un Pod lo referencie. Entonces el scheduler decide *primero* en qué nodo correr el Pod, considerando todas sus restricciones (requests, selectors, anti-affinity, topology spread). *Luego*, con el nodo decidido, el provisioner CSI crea el PV en la AZ de ese nodo. Imposible que haya conflicto.

**Regla práctica**: salvo justificación muy clara, usa `WaitForFirstConsumer` en cualquier cluster con más de una AZ (es decir, prácticamente cualquier cluster managed en producción).

En kind (single-node) la diferencia es *invisible en runtime*: solo hay una zona y un nodo. Pero el manifest debe ser correcto desde el principio. La actividad 02 vive aquí: te damos una StorageClass con `Immediate` + un Pod con `nodeSelector` zonal; en multi-AZ eso se rompe; en kind solo *parece* funcionar.

## 6. Reclaim policy y PVs huérfanos

Cuando borras un PVC:

- Con `reclaimPolicy: Delete`, el PV pasa a `Released` → `Deleting` → se borra junto con el disco cloud. Si borras un PVC de producción por error, perdiste los datos.
- Con `reclaimPolicy: Retain`, el PV pasa a `Released` y se queda. El disco subyacente *existe*. Para reusarlo:
  1. `kubectl edit pv <name>` y limpiar `spec.claimRef` (si existe) para que el PV vuelva a `Available`.
  2. Crear un PVC nuevo que exija exactamente ese PV (via `volumeName` o label matching).

Patrón defensivo en producción: StorageClass default con `Retain`. Patrón descartable en dev: `Delete`.

Se puede cambiar el reclaim policy de un PV ya creado con `kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'`. Muy útil cuando quieres hacer una operación destructiva (borrar un PVC) sin perder los datos.

## 7. CSI: la interfaz, los drivers y las realidades

**CSI (Container Storage Interface)** es la especificación que desacopla Kubernetes de los backends de almacenamiento. Antes de CSI (pre-1.13), los drivers vivían **dentro** del árbol de Kubernetes (`in-tree`); migrar a cualquier backend nuevo requería un release del kernel de K8s. Con CSI, los drivers son procesos externos (típicamente dos: un `controller` que corre centralizadamente y un `node` DaemonSet por nodo) que hablan gRPC con los componentes de K8s.

Drivers notables:

- **AWS EBS CSI** (`ebs.csi.aws.com`) — block, zonal, snapshots nativos.
- **GCP PD CSI** (`pd.csi.storage.gke.io`) — block, zonal o regional (regional = replicación síncrona entre dos AZ), snapshots.
- **Azure Disk CSI** — equivalente para Azure Managed Disks.
- **AWS EFS CSI** — RWX via NFS.
- **GCP Filestore CSI** — RWX via NFS.
- **Longhorn** — distributed block storage para bare-metal, replicación entre nodos.
- **local-path-provisioner** (Rancher) — ultra simple, usa `hostPath` del nodo. Default en kind, k3s. NO soporta snapshots. NO es portable entre nodos. Útil para desarrollo.
- **Portworx**, **Rook/Ceph**, **OpenEBS** — opciones más completas en self-hosted.

Al evaluar un CSI, mira: soporte de `VolumeSnapshot`, soporte de expansión online, soporte de RWX (si lo necesitas), topología (zonal vs regional), compatibilidad de versiones con K8s. No todos los drivers soportan todo.

## 8. VolumeSnapshot y VolumeSnapshotClass

Snapshots son copias puntuales del volumen a nivel de bloque, tomadas por el backend (no por K8s). Entrega tres recursos:

- **`VolumeSnapshotClass`** — análogo a `StorageClass` para snapshots. Define el `driver`, los `parameters` y el `deletionPolicy` (`Delete` vs `Retain`).
- **`VolumeSnapshot`** — el "pedido" de snapshot, namespace-scoped. Referencia un `PersistentVolumeClaim` como source y una `VolumeSnapshotClass`.
- **`VolumeSnapshotContent`** — el objeto que representa el snapshot *real* en el backend; es la contraparte "oferta", cluster-scoped. Se crea dinámicamente igual que un PV.

Ejemplo mínimo:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snap
driver: ebs.csi.aws.com
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pg-snap-2026-10-15
  namespace: db
spec:
  volumeSnapshotClassName: ebs-snap
  source:
    persistentVolumeClaimName: postgres-data
```

Restore se hace creando un **PVC nuevo** que apunte al snapshot como `dataSource`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-restored
  namespace: db
spec:
  storageClassName: fast-ssd
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
  dataSource:
    name: pg-snap-2026-10-15
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

Requisitos no obvios:

- **CRDs instalados**: `volumesnapshots`, `volumesnapshotcontents`, `volumesnapshotclasses` (del repo `kubernetes-csi/external-snapshotter`).
- **Snapshot controller** (sidecar `external-snapshotter`) desplegado en el cluster. En managed (EKS/GKE/AKS) suele venir con el add-on del CSI driver. En kind con `local-path` **no está** y el provisioner tampoco los soporta: hay que instalar algo como Longhorn si se quiere trabajar snapshots localmente.
- El PVC restaurado debe pedir *al menos* el tamaño del snapshot.

Esto es la base de "backup programado" en Kubernetes bien hecho: snapshot vía CronJob + script → upload opcional a object storage. Para backup *lógico* (`pg_dump`) hay que seguir usando `pg_dump`.

## 9. Expansión online y topología

**Expansión online**: con `allowVolumeExpansion: true` en la StorageClass y un CSI driver que lo soporte, puedes editar `pvc.spec.resources.requests.storage` a un valor mayor. El CSI expande el volumen cloud; luego el filesystem se expande sin desmontar (si es ext4/xfs). Nunca se puede *reducir*. Nunca.

**Topología**: en multi-AZ, los PVs son zonales. Los StatefulSets con PVC templates y un `topologySpreadConstraints` por `topology.kubernetes.io/zone` arman la geometría clásica "una réplica por AZ, cada una con su propio EBS". El scheduler respeta la topología siempre y cuando la StorageClass esté en `WaitForFirstConsumer`.

En GCP existen **Regional PDs**: PVs replicados síncronamente entre dos AZ. Permiten failover entre AZ sin perder datos, pero cuestan ~2× y latencia es mayor. En AWS no existe un equivalente nativo (EBS Multi-Attach es RWX pero con restricciones muy específicas; no es equivalente a Regional PD). Para HA real de datos en multi-AZ, el enfoque es "deja que la aplicación replique" (Postgres streaming replication, Kafka ISR, etc.).

## 10. Patrones correctos por tipo de workload

- **Base de datos relacional single-primary (Postgres, MySQL)**: PVC `RWO` por réplica, StorageClass con disco de buen IOPS, `WaitForFirstConsumer`, `reclaimPolicy: Retain` para producción, snapshots programados. Un operator (CloudNativePG, Zalando) hace replicación y failover por encima.
- **Base de datos distribuida (Cassandra, Elasticsearch, Kafka)**: PVC `RWO` por nodo via StatefulSet; la replicación la hace la aplicación.
- **Object cache (Redis sin AOF, Memcached)**: ningún PVC; `emptyDir` o nada.
- **Redis con AOF/RDB**: PVC `RWO` pequeño; con un operator si se quiere HA.
- **Build artifacts, modelos ML compartidos para read-only entre workers**: PVC `ROX` con filesystem compartido, o mejor, object storage.
- **CMS legacy que escribe uploads al disco**: PVC `RWX` con EFS/Filestore si no se puede refactorizar; migrar a S3/GCS cuando se pueda.
- **Logs de aplicación**: no PVC. Van a stdout → agent (Fluent Bit, Vector) → sink (Loki, ES, Cloud).

## 11. Fallos típicos y cómo depurarlos

- **PVC `Pending` para siempre con StorageClass `Immediate`**: `kubectl describe pvc` muestra `waiting for a volume to be created`. Causa posible: no hay un provisioner CSI escuchando (olvidaste instalarlo o la StorageClass apunta a un provisioner inexistente).
- **Pod `Pending` con mensaje `node(s) had volume node affinity conflict`**: el PV está en una AZ y el scheduler no puede poner el Pod ahí (otra AZ exigida por `nodeSelector`/`affinity`). Síntoma clásico de `Immediate` en multi-AZ. Fix: borrar PVC, cambiar StorageClass a `WaitForFirstConsumer`, recrear.
- **`FailedAttachVolume`**: el CSI node pod está crasheado en el nodo destino, o el volumen sigue attach-eado al nodo anterior (típico cuando se recrea el Pod en otro nodo y el detach tarda). En EBS puede llevar 1-2 minutos; paciencia o fuerzas detach vía API del cloud.
- **`FailedMount: special device does not exist`**: typo en `volumeMounts.name` o PVC inexistente.
- **PV huérfano en `Released` tras borrar PVC con `Retain`**: comportamiento esperado, no es un bug. Para reutilizar: limpiar `claimRef` o borrar el PV manualmente.
- **Expansión no ocurre**: verificar `allowVolumeExpansion: true` en la StorageClass, verificar que el CSI driver la soporta, y mirar eventos del PVC.

## 12. Resumen operativo

- PVC es el pedido (namespace-scoped). PV es la oferta (cluster-scoped). StorageClass intermedia y describe el "menú". CSI driver materializa.
- Usa `WaitForFirstConsumer` siempre que haya multi-AZ.
- Elige `Retain` en producción, `Delete` solo cuando los datos son prescindibles.
- RWO es lo normal. RWX es la excepción: justifícalo.
- Snapshots requieren CRDs + snapshot controller + driver que los soporte; no asumas que están en todo cluster.
- Expansión es solo hacia arriba.
- En kind, prácticamente todo es `local-path` single-node; úsalo para aprender la mecánica, no esperes snapshots ni topología.

Siguiente paso: pasa a los ejemplos y luego a las dos actividades.
