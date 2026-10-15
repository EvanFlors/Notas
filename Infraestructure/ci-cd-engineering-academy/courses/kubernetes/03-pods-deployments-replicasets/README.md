# k8s-03 — Pods, ReplicaSets y Deployments

## Identificación

- **ID:** `k8s-03-pods-deployments-replicasets`
- **Curso:** `kubernetes`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `k8s-02-setup-local-and-kubectl`. Haber hecho `kubectl` sobre un cluster local (kind o k3d).

## Objetivo

Modelar workloads **sin estado** con **Deployments** y entender qué es realmente un **Pod**: la unidad mínima de scheduling en Kubernetes y por qué casi nunca se crea "a mano" en producción. Al terminar deberías poder desplegar un servicio, actualizarlo sin downtime, interpretar el estado de un rollout y revertirlo a una revisión anterior con un solo comando.

## Alcance

Este módulo cubre:

- **Pod spec** completo: `containers`, `initContainers`, **sidecar containers nativos** (initContainer con `restartPolicy: Always`), `volumes`, `nodeSelector`, `restartPolicy`.
- Por qué los Pods no son el objeto correcto para desplegar servicios en producción.
- **ReplicaSet** como controlador de réplicas (y por qué rara vez se escribe directo).
- **Deployment**: estrategias `RollingUpdate` vs `Recreate`, parámetros `maxSurge`, `maxUnavailable`, `revisionHistoryLimit`.
- `kubectl rollout`: `status`, `history`, `undo`, `pause`, `resume`.
- **Labels y selectors** como contrato entre Deployment ↔ ReplicaSet ↔ Pod ↔ Service.

Lo que **no** cubre (se verá después):

- Services, DNS y acceso al workload → `k8s-04`.
- ConfigMap/Secret y volúmenes de configuración → `k8s-05`.
- StatefulSet, DaemonSet, Jobs → `k8s-06`.
- Probes (`liveness`/`readiness`/`startup`), `preStop` y rollout seguro al nivel 2 → `k8s-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-pod-vs-deployment/` — mismo workload desplegado como Pod bare y como Deployment; qué pasa al borrarlos.
  - `02-rolling-update-walkthrough/` — observar en vivo cómo un Deployment crea un nuevo ReplicaSet y escala viejo → nuevo.
  - `03-undo-with-rollout/` — romper un deploy a propósito y revertirlo con `kubectl rollout undo`.
- **`activities/`**:
  - `01-deploy-fastapi/` (guided-lab) — primer Deployment con labels, strategy explícita y rolling update verificado.
  - `02-rollout-and-rollback/` (independiente) — tres rollouts seguidos y rollback a una revisión intermedia.
- **`resources/links.md`** — documentación oficial y lecturas recomendadas.

## Temas y subtemas

1. **Pod**
   - Unidad de scheduling (uno o más contenedores que comparten red y volúmenes).
   - `restartPolicy` (Always/OnFailure/Never) y por qué un Deployment ignora los dos últimos.
   - `initContainers` secuenciales que corren antes del main.
   - **Sidecar containers nativos** (init con `restartPolicy: Always`): corren en paralelo al main, se inician antes y terminan después.
   - `volumes` (emptyDir, hostPath — ambos para introducir el concepto; detalle en `k8s-05`/`k8s-08`).
   - `nodeSelector` (introducción; afinidad avanzada en `k8s-09`).
2. **Por qué el Pod bare no es la respuesta en producción**
   - No se reprograma si el nodo muere.
   - No se auto-reemplaza si crashea con `restartPolicy: Never`.
   - No tiene réplicas, no tiene estrategia de actualización.
3. **ReplicaSet**
   - Mantiene N réplicas de un template.
   - Se escribe raramente; casi siempre lo gestiona un Deployment.
4. **Deployment**
   - `spec.replicas`, `spec.selector`, `spec.template`.
   - `strategy.type`: `RollingUpdate` (default) vs `Recreate`.
   - `rollingUpdate.maxSurge` y `maxUnavailable`.
   - `revisionHistoryLimit`.
5. **`kubectl rollout`**
   - `status` — bloquea hasta que termina.
   - `history` — lista las revisiones.
   - `undo` — vuelve a la anterior; `--to-revision=N` a una específica.
   - `pause` / `resume` — para combinar cambios en una sola rollout.
6. **Labels y selectors**
   - Metadata `labels` en Pod y Deployment.
   - `selector.matchLabels` como "contrato": Deployment reclama los Pods que tengan esas etiquetas.
   - Mismas etiquetas serán usadas por Services (`k8s-04`).

## Conceptos internos (fundamentos)

- Un **Deployment** no corre nada por sí mismo: crea un **ReplicaSet** cuyo template es el `spec.template` del Deployment, y es ese ReplicaSet quien crea Pods. Cada actualización del template genera un **nuevo ReplicaSet**; el viejo se escala a 0 (y permanece, hasta `revisionHistoryLimit`, para poder revertir).
- Los **labels** son el pegamento. Un Deployment "sabe" qué Pods son suyos porque su `selector.matchLabels` coincide con las labels del template. Un Service "sabe" a qué Pods enrutar por el mismo mecanismo. **Cambiar `selector` después de crear el Deployment es una operación destructiva** (crea otro set de Pods).
- Un **rolling update** respeta dos restricciones simultáneas: nunca haber más de `replicas + maxSurge` Pods a la vez, y nunca menos de `replicas - maxUnavailable` Pods *disponibles*. "Disponible" se mide con readiness probes (si no las defines, cuenta como disponible al estar `Running`).
- Un **sidecar nativo** es un `initContainer` con `restartPolicy: Always`. El kubelet lo arranca antes que los containers normales, lo mantiene vivo durante toda la vida del Pod, y lo termina **después** de los containers normales. Resuelve problemas que los sidecars "clásicos" (contenedores normales que corren en paralelo) tenían con `Jobs` y con shutdown ordenado.
- `restartPolicy` **a nivel de Pod** aplica a todos los contenedores no-init del Pod. Un Deployment siempre asume `Always` (los otros valores no tienen sentido para un servicio de larga vida). Si lo pones distinto en el template, el API lo rechaza.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un Pod bare no es "la forma K8s" de desplegar un servicio. Explicar cómo un Deployment orquesta dos ReplicaSets durante un rolling update. Diferenciar `RollingUpdate` de `Recreate` y cuándo usar cada uno. |
| Operativa | Escribir un Deployment desde cero con labels y selector correctos; actualizar la imagen y observar el rollout; revertir con `rollout undo`; interpretar `kubectl rollout status`. |
| Arquitectónica | Decidir `maxSurge`/`maxUnavailable` según costo vs disponibilidad; justificar un `revisionHistoryLimit` razonable; identificar el riesgo de usar `Recreate` para servicios de usuario. |

## Entregables

- Un Deployment funcional del capstone (o del stand-in `nginxdemos/hello` / `nginx`) con rolling update verificado en cluster local.
- Historial de al menos 3 revisiones y un rollback demostrado a una revisión intermedia.
- Los dos `tests/validate.sh` de las actividades deben pasar (o imprimir `SKIP` si no hay cluster disponible).

## Criterios de evaluación

- Capacidad de **explicar por qué modificar un Pod directo no es "la forma K8s"**: no hay reconciliación, no sobrevive al nodo, no se reprograma, no tiene revisiones.
- Capacidad de leer un Deployment ajeno e identificar: qué pasa en un rollout, cuántos Pods pueden coexistir, si una actualización respetará el presupuesto de disponibilidad.
- Capacidad de depurar un rollout estancado (`kubectl rollout status` queda esperando) distinguiendo entre: imagen inválida (`ImagePullBackOff`), readiness fallando, o selector/labels mal escritos.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-pod-vs-deployment/` y responde las preguntas de reflexión.
3. Haz `activities/01-deploy-fastapi/`.
4. Reproduce `examples/02-rolling-update-walkthrough/` observando los ReplicaSets.
5. Reproduce `examples/03-undo-with-rollout/`.
6. Haz `activities/02-rollout-and-rollback/` sin mirar la solución.

## Siguiente

→ `k8s-04-services-and-dns`: expondremos el Deployment por nombre DNS dentro del cluster.
