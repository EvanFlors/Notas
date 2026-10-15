# Ejemplo 02 — Walkthrough de `spec` vs `status` en un Deployment real

## Concepto que demuestra

Todo recurso en Kubernetes tiene dos partes: `spec` (deseado, lo escribe un humano/CI) y `status` (observado, lo escriben controllers o el kubelet). En este ejemplo lees un **par capturado** y aprendes a identificar quién escribió qué.

## Contexto

En `theory/lesson.md` §2.1 vimos la *descripción*. Aquí lo tocas: un Deployment real (ligeramente simplificado) separado en dos archivos para enfatizar la frontera `spec` / `status`.

## Objetivo

Al terminar, podrás:

- Señalar qué campos son `spec` (deseo del usuario) y qué campos son `status` (observación del sistema).
- Identificar quién escribe cada parte del `status` (Deployment controller, ReplicaSet controller, kubelet).
- Explicar qué pasa en `metadata.generation` vs `status.observedGeneration` cuando reconfiguras.
- Explicar por qué `metadata.resourceVersion` cambia constantemente y para qué sirve.

## Prerrequisitos

- Haber leído §2 y §5 de `theory/lesson.md`.

## Archivos

- **`files/deployment-spec.yaml`** — lo que escribió el usuario (o CI). Es lo que subes a Git.
- **`files/deployment-status.yaml`** — el mismo objeto como lo devuelve el API server tras un rato de reconciliación: ahora tiene `metadata.resourceVersion`, `metadata.generation`, un `status` completo, campos `creationTimestamp`, `uid`, etc.

Son archivos **de ejemplo** (ligeramente simplificados). Si tuvieras cluster, obtendrías algo equivalente con:

```bash
# Requiere cluster + kubectl (opcional):
kubectl get deployment web -o yaml
```

## Ejecución

### Paso 1 — Lee `files/deployment-spec.yaml`

Es lo que escribirías tú. Nota:

- Hay solo `apiVersion`, `kind`, `metadata.name`, y `spec`.
- `metadata` tiene **solo** `name` (y quizá `namespace`, `labels`). **No** hay `uid`, ni `creationTimestamp`, ni `resourceVersion`, ni `generation`. Esos los pone el API server al crear.
- **No** hay `status`. Nunca lo escribas tú.

### Paso 2 — Lee `files/deployment-status.yaml`

Es el **mismo objeto** después de que el usuario lo creó y el sistema reconcilió. Compara línea a línea con el spec. Diferencias:

- `metadata.uid` — identificador único asignado por el API server al crear. **Nunca cambia** durante la vida del objeto.
- `metadata.creationTimestamp` — cuándo se creó. **Nunca cambia**.
- `metadata.generation` — contador que se incrementa cada vez que cambia el `spec`. Permite a los controllers saber "¿esta versión del spec ya la procesé?".
- `metadata.resourceVersion` — contador global del API server; cambia **con cualquier update** (incluso al `status`). Se usa para optimistic concurrency (`PATCH` con `resourceVersion` falla si ya cambió — evita race conditions).
- `metadata.managedFields` — tracking server-side-apply de quién gestiona cada campo (lo pone el API server automáticamente).
- `status.observedGeneration` — el `metadata.generation` que el **Deployment controller** vio y procesó por última vez. Si `observedGeneration < generation`, el controller aún no reconciló tu último cambio.
- `status.replicas` — cuántos Pods existen matching el selector (lo escribe el Deployment controller).
- `status.availableReplicas` — cuántos están Ready y han pasado `minReadySeconds` (lo escribe el Deployment controller observando el ReplicaSet).
- `status.readyReplicas` — cuántos están en condición `Ready` (viene del ReplicaSet, derivado del `status` de los Pods, que lo escribe el **kubelet**).
- `status.conditions` — array de condiciones (`Available`, `Progressing`), cada una con `status`, `reason`, `message`, `lastTransitionTime`.

### Paso 3 — Identifica quién escribe cada parte del `status`

```
Campo                                  Escrito por
─────────────────────────────────────  ─────────────────────────────
status.observedGeneration              Deployment controller
status.replicas                        Deployment controller
status.updatedReplicas                 Deployment controller
status.availableReplicas               Deployment controller
status.readyReplicas                   Deployment controller
                                       (derivado del RS, que a su vez
                                        es derivado de los Pods)
status.conditions[]                    Deployment controller
```

El Deployment controller **no mira los Pods directamente** — mira el ReplicaSet que gestiona, que a su vez mira los Pods. Cadena: `kubelet → Pod.status → ReplicaSet.status → Deployment.status`.

### Paso 4 — Correlaciona `generation` y `observedGeneration`

Supón que haces `kubectl edit deployment web` y cambias `spec.replicas` de 3 a 5:

```
Antes del edit:
  metadata.generation: 1
  status.observedGeneration: 1
  spec.replicas: 3
  status.replicas: 3

Inmediatamente después del edit (API server procesó, controller aún no):
  metadata.generation: 2
  status.observedGeneration: 1   ← todavía la vieja
  spec.replicas: 5
  status.replicas: 3

Tras la reconciliación completa (controller actuó, ReplicaSet escaló, kubelet
arrancó Pods, status propagó):
  metadata.generation: 2
  status.observedGeneration: 2   ← al día
  spec.replicas: 5
  status.replicas: 5
  status.availableReplicas: 5
```

**Esta es la señal más precisa** de "¿terminó mi deploy?": `status.observedGeneration == metadata.generation` **y** `status.availableReplicas == spec.replicas`. `kubectl rollout status` eso es lo que mira.

### Paso 5 — `resourceVersion` y optimistic concurrency

`metadata.resourceVersion` cambia **con cualquier escritura al objeto** — incluso cuando el controller actualiza solo `status`. Es un **monotónico global** del API server (técnicamente del revision de etcd). Sirve para dos cosas:

- **Optimistic concurrency en updates**: si tú lees un objeto con `resourceVersion=12345`, modificas algo, y haces `PUT` con `resourceVersion=12345`, el API server rechaza con `409 Conflict` si alguien más ya escribió (y lo subió a `12346`). Reintentas con la versión fresca. Evita last-write-wins.
- **WATCH incremental**: un controller abre `WATCH` desde `resourceVersion=12345` y recibe solo los eventos posteriores. Si se desconecta y reconecta, pide desde la última versión vista. Esto es cómo los controllers se mantienen actualizados sin re-leer todo constantemente.

## Resultado esperado

Después del walkthrough deberías poder:

- Señalar en un YAML cualquiera qué es `spec` y qué es `status`.
- Explicar por qué nunca modificas `status` a mano.
- Explicar la cadena `generation → observedGeneration` y cómo `kubectl rollout status` la usa.
- Explicar `resourceVersion` y para qué sirve en WATCH y en updates.

## Interpretación

- **`spec` es "contrato con el usuario"**; **`status` es "reporte del sistema"**. La frontera es sagrada.
- Un recurso **sin `status`** aún es válido — significa "lo creaste pero nadie reconcilió todavía". Pasa normalmente los primeros milisegundos tras un `apply`.
- La "sub-resource `/status`" existe explícitamente en el API server: controllers que escriben solo `status` usan `PATCH /apis/.../status`, lo que evita conflictos con escrituras al `spec`. Esto lo verás con CRDs en `k8s-14`.
- **El RBAC puede separar escritura de `spec` y de `status`** — los controllers del sistema tienen permisos de escribir `/status` pero no `/spec`, lo cual es correcto por diseño.

## Errores frecuentes

- **Editar `status` a mano** — inútil (el controller lo pisa) y puede causar inconsistencias.
- **Pensar que `generation` y `resourceVersion` son lo mismo** — no. `generation` cambia solo con `spec`; `resourceVersion` cambia con **cualquier** escritura.
- **Pensar que `status.replicas` == `spec.replicas` siempre** — no: durante un rollout, difieren. Esa es su utilidad.
- **Confundir `readyReplicas` con `availableReplicas`** — `ready` es "el Pod reporta ready"; `available` es "ready **y** ha pasado `minReadySeconds`". `available` es el que importa para `kubectl rollout status`.

## Relación con escenarios reales

- **GitOps (Argo CD / Flux)**: solo pushean cambios al `spec` del cluster; nunca al `status`. El sistema reconcila.
- **Operadores**: un operador propio es un controller que mira `spec` de su CRD, actúa, y escribe `status`. Mismo patrón.
- **`kubectl rollout status`**: mira `generation`, `observedGeneration`, `availableReplicas`. Si `generation=5` y `observedGeneration=4`, "el controller aún no vio tu último cambio".
- **CRDs con sub-resource `/status`**: diseño correcto para evitar conflictos entre quien escribe `spec` (humano) y quien escribe `status` (controller).

## Limpieza

Nada que limpiar — todo son archivos de lectura dentro del repo.
