# k8s-08-01 — Persistir Postgres con PVC y VolumeSnapshot

## 1. Identificación

- **ID:** `k8s-08-01-persist-postgres-with-snapshot`
- **Tecnología:** kubernetes
- **Módulo:** `08-storage-pv-pvc-storageclass-csi`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes que persistir el estado de un Postgres y producir snapshots que puedas restaurar en otro PVC. Es el patrón canónico de "backup programado" nativo de K8s para almacenamiento de bloque.

Esta actividad corre contra un cluster **kind**. Como `local-path-provisioner` (default en kind) **no soporta snapshots**, la parte de persistencia se verifica en runtime, y la parte de snapshot se valida *estáticamente* sobre los manifests. Si corres esto en un cluster con un CSI que sí los soporte (EKS con `aws-ebs-csi-driver` + snapshotter), el runtime del snapshot también funcionará: el validador detecta la disponibilidad y actúa en consecuencia.

## 3. Objetivos

- Desplegar Postgres contra un PVC dinámico; probar que los datos sobreviven a borrar y recrear el Pod.
- Escribir un manifest de `VolumeSnapshotClass` + `VolumeSnapshot` que apunte al PVC de Postgres.
- Escribir un manifest de PVC de *restore* con `dataSource` referenciando el snapshot.

## 4. Prerrequisitos

- `kubectl` ≥ 1.28.
- `kind` instalado y un cluster corriendo (`kind create cluster --name k8s08`).
- Si no hay `kind`/`kubectl` o el cluster no es alcanzable, el validador salta con exit 0.
- Imagen `postgres:16-alpine` (~230 MB de pull).
- Namespace de trabajo: `k8s08-pg` (se crea si no existe).

Costo: 0. Todo local.

## 5. Instrucciones

Es guiada: ejecuta `starter/run.sh`. Hace lo siguiente paso a paso:

1. Verifica `kubectl` + cluster alcanzable (SKIP si no).
2. Crea namespace `k8s08-pg`.
3. Aplica `starter/manifests/pvc.yaml` (PVC dinámico, 1 GiB, StorageClass default `standard` de kind).
4. Aplica `starter/manifests/pod.yaml` (Pod de Postgres).
5. Espera a Postgres listo (via `psql` dentro del Pod).
6. `CREATE TABLE marcadores` + `INSERT`.
7. Borra el Pod. El PVC sigue vivo.
8. Recrea el Pod. Verifica que la fila persiste.
9. Aplica `starter/manifests/volumesnapshotclass.yaml` y `starter/manifests/volumesnapshot.yaml` (si los CRDs están instalados; si no, los imprime y los deja en disco para validación estática).

```bash
cd courses/kubernetes/08-storage-pv-pvc-storageclass-csi/activities/01-persist-postgres-with-snapshot
bash starter/run.sh
```

Luego:

```bash
bash tests/validate.sh
```

Y limpia:

```bash
bash starter/cleanup.sh
```

## 6. Resultado esperado

- Namespace `k8s08-pg` existe.
- PVC `pg-data` en estado `Bound`.
- Pod `pg` corriendo con la fila `persisted-by-k8s-08-01` recuperable después de un ciclo `delete pod` + `apply pod`.
- Manifests `volumesnapshotclass.yaml`, `volumesnapshot.yaml` y `pvc-restored.yaml` existen y son YAML válidos con los campos correctos (`kind`, `apiVersion`, `source.persistentVolumeClaimName`, `dataSource.kind: VolumeSnapshot`, etc.).

## 7. Criterios de aceptación

- `bash tests/validate.sh` exit code 0.
- La persistencia debe demostrarse en runtime (si el cluster está disponible).
- Los manifests de snapshot deben validar aunque no haya CSI con snapshots.

## 8. Validación

```bash
bash tests/validate.sh
```

Se verifica:

- `kubectl` + cluster disponibles → sino SKIP.
- Namespace existe.
- PVC `pg-data` `Bound`.
- Pod `pg` `Running`.
- Query `SELECT nota FROM marcadores` retorna la fila esperada.
- Los tres manifests de snapshot/restore existen en el directorio y son YAML válidos con los campos esperados.
- Si los CRDs `volumesnapshots.snapshot.storage.k8s.io` están registrados, verifica que el `VolumeSnapshot` fue creado.

## 9. Preguntas de reflexión

- ¿Qué `kubectl describe pv` revela sobre el PV creado por `local-path`? ¿Dónde está el disco físico realmente?
- Si cambiases la StorageClass a una `WaitForFirstConsumer` (en EKS/GKE), ¿qué cambia en la secuencia de eventos de `kubectl describe pvc`?
- ¿Qué pasa si creas el PVC de restore con `storage` *menor* que el PVC origen?
- En producción con `reclaimPolicy: Delete`, borraste accidentalmente el PVC. ¿Qué pasó con el disco? ¿Cómo lo evitarías?

## 10. Extensiones

1. Programa un `CronJob` que crea un `VolumeSnapshot` con nombre `pg-snap-$(date +%Y%m%d-%H%M)` cada hora (requiere un cluster con snapshots funcionales).
2. Reemplaza el Pod por un `StatefulSet` con `volumeClaimTemplates`; discute por qué eso es lo correcto en producción.
3. Instala `aws-ebs-csi-driver` en un EKS y corre esta actividad con snapshots reales.

## 11. Limpieza

```bash
bash starter/cleanup.sh
```

Borra el namespace entero (lo que lleva consigo PVC, Pod y VolumeSnapshot).
