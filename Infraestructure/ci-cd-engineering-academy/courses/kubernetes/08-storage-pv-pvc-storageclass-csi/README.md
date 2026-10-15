# k8s-08 — Storage: PV, PVC, StorageClass y CSI

## Identificación

- **ID:** `k8s-08-storage-pv-pvc-storageclass-csi`
- **Curso:** `kubernetes`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `k8s-06-workloads-deep-statefulset-daemonset-jobs`.

## Objetivo

Persistir estado correctamente en Kubernetes: elegir el tipo de almacenamiento adecuado por workload, entender la relación **PVC → StorageClass → PV → CSI driver**, dominar `volumeBindingMode`, reclaim policies y snapshots, y ser capaz de operar un Postgres respaldado por un `VolumeSnapshot` con restore demostrable.

## Alcance

Este módulo cubre:

- **PersistentVolume (PV)** y **PersistentVolumeClaim (PVC)**: pedido/oferta, binding, estados (`Pending`, `Bound`, `Released`, `Failed`).
- **StorageClass** y provisioning dinámico.
- **CSI drivers** del ecosistema (AWS EBS, GCP Persistent Disk, Azure Disk, Longhorn, local-path, EFS/Filestore para RWX).
- **Access modes**: `ReadWriteOnce` (RWO), `ReadOnlyMany` (ROX), `ReadWriteMany` (RWX), `ReadWriteOncePod` (RWOP).
- **`volumeBindingMode`**: `Immediate` vs `WaitForFirstConsumer` (crítico en multi-AZ).
- **Reclaim policies**: `Delete` vs `Retain`.
- **VolumeSnapshot** y **VolumeSnapshotClass**; restore desde snapshot via `dataSource`.
- Expansión online (`allowVolumeExpansion`).
- Cuándo RWX (EFS/Filestore/CephFS) tiene sentido y cuándo es un anti-patrón.

Lo que **no** cubre (viene luego):

- Operadores de bases de datos (CloudNativePG, Strimzi) → `k8s-14`.
- Backup *de recursos K8s* con Velero → `k8s-17`.
- GPU/DRA storage → fuera de alcance.

## Materiales

- **`theory/lesson.md`** — 12 secciones.
- **`examples/`**:
  - `01-pvc-dynamic-ebs/` — manifests de referencia para EBS en EKS; versión runnable con `local-path` en kind.
  - `02-waitforfirstconsumer-vs-immediate/` — dos StorageClass lado a lado, para contrastar binding.
  - `03-volumesnapshot-and-restore/` — manifests completos para VolumeSnapshotClass + VolumeSnapshot + restore vía `dataSource`; walkthrough de kind (donde no hay CSI snapshotter por default).
- **`activities/`**:
  - `01-persist-postgres-with-snapshot/` — guided lab: Postgres con PVC + snapshot (manifest) + restore (manifest). Runtime completo en EKS/GKE; en kind se valida la corrección de los manifests.
  - `02-fix-pv-wrong-az/` — independent debug: la StorageClass está en `volumeBindingMode: Immediate` y el Pod tiene `nodeSelector` a una zona específica → PVC se liga en otra AZ y el Pod queda `Pending`. Arreglar.
- **`resources/links.md`**.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar binding dinámico, el papel de la `StorageClass`, qué diferencia `Immediate` de `WaitForFirstConsumer`, y por qué `Immediate` genera PV en AZ equivocada en multi-AZ. Diferenciar los cuatro `accessModes` y entender que son *contrato con el CSI*, no magia. |
| Operativa | Crear PVCs dinámicos, inspeccionar PVs ligados, cambiar reclaim policy sin perder datos, tomar un `VolumeSnapshot`, restaurar un PVC desde snapshot, expandir online. |
| Arquitectónica | Diseñar storage por workload (DB vs object cache vs logs); decidir entre RWO con sharding y RWX con filesystem compartido; evaluar un CSI por su madurez de snapshot y expansión. |

## Entregables

- Postgres respaldado por PVC con snapshot programado y restore demostrado (en EKS/GKE si está disponible; manifests validados staticamente en kind).
- Un ADR de 1 página: "cuándo RWX tiene sentido en este sistema".
- Diagnóstico escrito del escenario de actividad 02: por qué el Pod quedó `Pending`, qué habría pasado en multi-AZ real y cuál es la corrección.

## Criterios de evaluación

- **Conceptual**: explicar `volumeBindingMode` sin consultar docs y por qué `Immediate` genera errores en multi-AZ.
- **Operativa**: `scripts/validate-activities.py` pasa; validadores de ambas actividades OK; capacidad de "leer" los PV/PVC con `kubectl describe` y rastrear el estado.
- **Arquitectónica**: ante un escenario (DB OLTP, cache efímera, modelo ML compartido entre workers) proponer el storage correcto con justificación.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Revisa `examples/01-pvc-dynamic-ebs/` (lee aunque no tengas EKS; usa el apartado kind al final).
3. Revisa `examples/02-waitforfirstconsumer-vs-immediate/` ejecutando los manifests en kind.
4. Revisa `examples/03-volumesnapshot-and-restore/` leyendo el walkthrough si estás en kind.
5. Haz `activities/01-persist-postgres-with-snapshot/` (guided).
6. Haz `activities/02-fix-pv-wrong-az/` (debug, sin ver la solución primero).
7. Responde las preguntas de evaluación.

## Nota sobre el entorno

Las actividades y ejemplos están diseñados para **kind** (cluster local, single-node). Dos consecuencias:

- No hay `topology.kubernetes.io/zone`: no se puede *observar* en vivo el bug de `Immediate` en multi-AZ. Lo que sí se puede es escribir los manifests correctos y razonar sobre el fallo. La actividad 02 valida *la corrección del manifest*.
- No hay CSI snapshotter instalado por default. El provisioner default en kind es `local-path` (Rancher), que **no soporta `VolumeSnapshot`**. La actividad 01 tiene dos modos: *runtime* (si detecta `volumesnapshots.snapshot.storage.k8s.io` registrado y una `VolumeSnapshotClass` disponible) o *static* (valida que los manifests estén correctos).

Está documentado explícitamente en cada README.

## Siguiente

→ `k8s-09-scheduling-resources-affinity-taints-pdb`.
