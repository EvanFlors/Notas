## k8s-06 — Workloads deep: StatefulSet, DaemonSet, Jobs y CronJobs

## Identificación

- **ID:** `k8s-06-workloads-deep-statefulset-daemonset-jobs`
- **Curso:** `kubernetes`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`, `k8s-04-services-and-dns`.

## Objetivo

Elegir el **workload controller correcto** por tipo de carga: Deployment para apps *stateless*; **StatefulSet** cuando la identidad, el orden y el almacenamiento por réplica importan; **DaemonSet** cuando necesitas *una copia por nodo*; **Job**/**CronJob** cuando el trabajo es *finito* (one-shot o programado). Al terminar deberías operar un **Postgres via StatefulSet con PVC** con criterio (saber escalarlo, recuperarlo, y defender *si realmente conviene correrlo en K8s* para tu caso).

## Alcance

Este módulo cubre:

- **StatefulSet**: identidad estable (`<name>-0`, `<name>-1`), DNS predecible vía headless service, PVC templates (`data-<name>-0`), orden de inicio/parada, política `podManagementPolicy` (`OrderedReady` vs `Parallel`), `volumeClaimTemplates`, por qué eliminar el STS **no borra los PVC** (por diseño: salvaguarda de datos).
- **DaemonSet**: un Pod por nodo que cumpla los criterios (tolerations, `nodeSelector`, `affinity`); patrones de uso: *log forwarders* (fluent-bit, Vector), *CNI agents*, *node-exporter*, almacenamiento (Longhorn), *security agents* (Falco).
- **Job**: una ejecución que debe terminar con éxito; `completions`, `parallelism`, `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`; **indexed Jobs** (`completionMode: Indexed`); patrones *worker queue* y *leader election*.
- **CronJob**: schedule tipo cron (interpretado en **UTC**), `concurrencyPolicy` (`Allow` | `Forbid` | `Replace`), `startingDeadlineSeconds`, `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`, `suspend`.
- Criterios para **elegir controller** por tipo de carga.
- Discusión honesta: **por qué un StatefulSet no es un DBA**; cuándo correr una DB en K8s (y cuándo no) — se demuestra con un Postgres mínimo y se compara con usar un operador o un servicio managed.

Lo que **no** cubre (se verá después):

- Detalles de `PV`, `PVC`, `StorageClass`, `VolumeSnapshot` → `k8s-08-storage-pv-pvc-storageclass-csi`.
- `NetworkPolicy`, `Ingress`, `Gateway API` → `k8s-07`.
- Autoscaling (HPA/KEDA/Karpenter) → `k8s-13`.
- Operadores de Postgres (CloudNativePG, Zalando) → `k8s-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones).
- **`examples/`**:
  - `01-postgres-via-statefulset/` — Postgres 16 corriendo como `StatefulSet` con PVC por réplica y headless service. Demuestra identidad estable, DNS, persistencia a través de un `delete pod`.
  - `02-fluent-bit-daemonset/` — fluent-bit como `DaemonSet` recolectando logs del nodo. Demuestra el patrón "un agent por nodo".
  - `03-cronjob-cleanup/` — `CronJob` que corre cada minuto una tarea de "limpieza" (educativa). Demuestra schedule UTC, `concurrencyPolicy`, historial y `startingDeadlineSeconds`.
- **`activities/`**:
  - `01-stateful-postgres-with-pvc/` *(guided-lab)* — levantar Postgres con `StatefulSet` + headless service + PVC templates y demostrar que el dato sobrevive a `delete pod`.
  - `02-cronjob-flaky-fix/` *(debug independiente)* — un `CronJob` con `concurrencyPolicy: Allow` y un comando lento genera overlaps; investigar y arreglar eligiendo `Forbid` o `Replace` + fijar `startingDeadlineSeconds`.
- **`resources/links.md`** — documentación oficial, KEPs, lecturas.

## Temas y subtemas

1. **Mapa de controllers por tipo de carga**
   - Stateless → `Deployment` (ya visto en k8s-03).
   - Stateful con identidad por réplica → `StatefulSet`.
   - Un Pod por nodo → `DaemonSet`.
   - Trabajo finito que debe completarse → `Job`.
   - Trabajo finito recurrente → `CronJob`.
2. **StatefulSet a fondo**
   - Identidad estable: `<name>-0`, `<name>-1`, `<name>-2`.
   - Headless `Service` (`clusterIP: None`) **obligatorio** para DNS por Pod.
   - `volumeClaimTemplates` → PVC `data-<name>-0`, `data-<name>-1`.
   - `podManagementPolicy`: `OrderedReady` (default, uno a la vez) vs `Parallel`.
   - `updateStrategy`: `RollingUpdate` (de mayor ordinal a menor) + `partition`; `OnDelete`.
   - Scaling: ordenado hacia arriba y hacia abajo.
   - Eliminar el STS **no borra los PVC** (salvo `persistentVolumeClaimRetentionPolicy` explícito).
3. **DaemonSet**
   - Un Pod por nodo que satisfaga el selector + tolerations.
   - Casos: log collector, CNI, node-exporter, storage, seguridad.
   - Interacción con taints (control plane) y con nodos nuevos (se auto-despliega).
   - `updateStrategy`: `RollingUpdate` con `maxUnavailable` (default 1) o `OnDelete`.
4. **Job**
   - `completions` y `parallelism` (NxM: cuántas instancias simultáneas y cuántas éxitos requeridos).
   - `backoffLimit` (reintentos del Pod).
   - `activeDeadlineSeconds` (deadline hard).
   - `ttlSecondsAfterFinished` (auto-GC del Job al terminar).
   - `restartPolicy` del Pod: solo `OnFailure` o `Never` (no `Always`).
5. **Indexed Jobs**
   - `completionMode: Indexed` → cada Pod recibe `JOB_COMPLETION_INDEX` como env var y como hostname sufijo.
   - Patrón para *static work partitioning* (particionar dataset por índice).
6. **Worker queue y leader election**
   - Patrón *queue + workers*: un `Job` con `parallelism: N`, cada Pod toma trabajo de una cola externa (Redis/SQS/Rabbit).
   - *Leader election* vía `coordination.k8s.io/Lease` para que de N réplicas de un controller solo una actúe.
7. **CronJob**
   - Schedule tipo cron (`m h dom mon dow`) **evaluado en UTC** por default (hay flag `spec.timeZone` en GA desde 1.27).
   - `concurrencyPolicy`:
     - `Allow` (default) — overlap permitido; peligroso para jobs lentos.
     - `Forbid` — si el anterior sigue corriendo, se **salta** la ejecución.
     - `Replace` — mata al anterior y lanza el nuevo.
   - `startingDeadlineSeconds` — si no pudo arrancarse dentro de esa ventana, se cuenta como "missed".
   - `successfulJobsHistoryLimit` (default 3) y `failedJobsHistoryLimit` (default 1).
   - `suspend: true` — pausa sin borrar.
8. **PVC lifecycle en StatefulSet**
   - Un PVC por réplica, creado al escalar hacia arriba.
   - Nunca borrado automáticamente al escalar hacia abajo o al borrar el STS (default).
   - `persistentVolumeClaimRetentionPolicy` (`whenScaled`, `whenDeleted`) permite afinarlo, pero el default conservador es `Retain`.
9. **Headless Service y DNS**
   - `clusterIP: None` → DNS por Pod: `<pod>.<svc>.<ns>.svc.cluster.local`.
   - Necesario para que la app sepa a qué réplica concreta hablar (p. ej., primario de Postgres).
10. **Elegir el controller correcto**
    - Checklist de preguntas: ¿la carga tiene estado por réplica? ¿orden importa? ¿necesita hostname estable? ¿debe correr en cada nodo? ¿termina alguna vez? ¿es recurrente?
11. **"StatefulSet no es un DBA"**
    - K8s te da *mecánica*: identidad, PVC, scheduling.
    - No te da *conocimiento operacional*: backup, PITR, failover, upgrades mayores, tuning.
    - Opciones: operador maduro (CNPG, Zalando) *o* servicio managed (RDS/CloudSQL) *o* self-managed fuera del cluster.
12. **Internals**
    - El `StatefulSet` controller reconcilia **ordenadamente**: crea `-0`, espera `Ready`, crea `-1`.
    - El `DaemonSet` controller escucha Node events y crea Pods cuando aparece un nodo apto.
    - El `Job` controller crea Pods, cuenta éxitos vs `completions`, y respeta `backoffLimit`.
    - El `CronJob` controller calcula ventanas de ejecución **en UTC** (salvo `spec.timeZone`), consulta `startingDeadlineSeconds` para decidir qué hacer con ventanas perdidas, y crea Jobs hijos.

## Conceptos internos (fundamentos)

- **Identidad estable** significa que `postgres-0` *siempre* es `postgres-0` — mismo hostname, mismo PVC, mismo DNS. Esto permite construir patrones de consenso (primario/réplica) sin coordinación externa.
- Un **headless Service** no asigna VIP; en su lugar, CoreDNS devuelve un *A record* por Pod. Sin esto, no hay `postgres-0.postgres.default.svc.cluster.local`.
- Los **PVC de un StatefulSet no se borran** al eliminar el STS. Es intencional. Si realmente quieres borrarlos, hazlo explícito con `kubectl delete pvc -l app=...` o usa `persistentVolumeClaimRetentionPolicy`.
- Un **DaemonSet** se escala con los nodos: añade un nodo y aparece un Pod ahí; drena un nodo y el Pod del DS tolera (o no) ese drain según sus tolerations.
- Un **CronJob calcula sus ventanas en UTC**; si tu equipo razona en zona local, pon `spec.timeZone` explícito. Un cambio de DST ha hecho producción histórica suficiente como para que esto no se olvide.
- `concurrencyPolicy: Allow` + un job que **a veces** dura más que su intervalo = colisiones silenciosas; corrupción si tocan el mismo recurso.
- **StatefulSet no es un DBA**: te da los primitivos para operar algo con estado, pero *tú* tienes que resolver backup, failover, PITR, upgrades. Para Postgres en serio: operador o managed.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué controller usar para 10 escenarios distintos. Explicar por qué un StatefulSet necesita un headless service. Explicar por qué el STS *no* borra PVCs y por qué eso es *bueno*. |
| Operativa | Levantar un Postgres via `StatefulSet` con PVC y demostrar persistencia tras `delete pod`. Diagnosticar un CronJob con overlaps y arreglarlo con `concurrencyPolicy` + `startingDeadlineSeconds`. |
| Arquitectónica | Defender si *conviene o no* operar una base de datos en K8s para un caso dado, con criterios de madurez de equipo, criticidad del dato y existencia de managed. |

## Entregables

- Postgres funcional via `StatefulSet` con PVC persistente (verificado: borrar el Pod, Pod vuelve, dato sigue ahí).
- `tests/validate.sh` de las dos actividades: **PASS**.
- ADR corto (3-5 bullets) en tus notas: "operaría Postgres en K8s para X escenario — sí/no — porque…".

## Criterios de evaluación

- Capacidad de **leer un manifest** y decir "esto debería ser un StatefulSet, no un Deployment, porque X".
- Capacidad de **recuperar** un StatefulSet tras un `delete pod` y explicar por qué el PVC sobrevivió.
- Capacidad de **diagnosticar** un CronJob con overlaps leyendo `kubectl get jobs`.
- Capacidad de **justificar** la decisión de operar o no una DB en K8s para un caso dado.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-postgres-via-statefulset/` paso a paso.
3. Reproduce `examples/02-fluent-bit-daemonset/` y observa que aparece un Pod por nodo.
4. Reproduce `examples/03-cronjob-cleanup/`.
5. Haz `activities/01-stateful-postgres-with-pvc/`.
6. Haz `activities/02-cronjob-flaky-fix/`.
7. Responde la pregunta de evaluación (operar DB en K8s o no) por escrito, sin consultar.

## Siguiente

→ `k8s-07-networking-cni-netpol-ingress-gateway-api`: controlar tráfico este-oeste y norte-sur con primitivas correctas.
