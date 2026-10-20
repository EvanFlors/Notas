# k8s-09 — Scheduling, recursos, afinidad, taints y PDB

## Identificación

- **ID:** `k8s-09-scheduling-resources-affinity-taints-pdb`
- **Curso:** `kubernetes`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`. Útil haber visto `k8s-02` (kind) y `k8s-04` (Services).

## Objetivo

Controlar **dónde** corren los Pods y **bajo qué recursos** lo hacen. Al terminar deberías poder: declarar `requests/limits` realistas; explicar la diferencia entre **OOMKill** y **CPU throttling** por síntomas; usar **affinity/anti-affinity**, **taints/tolerations**, **topologySpreadConstraints** y `nodeSelector` con criterio; proteger una app crítica con un **PodDisruptionBudget** verificable contra `kubectl drain`.

## Alcance

Este módulo cubre:

- `resources.requests` y `resources.limits` para CPU, memoria y `ephemeral-storage`.
- **QoS classes** derivadas: `Guaranteed`, `Burstable`, `BestEffort`.
- Qué pasa en el kernel cuando se excede un límite: **OOMKill** (memoria) vs **cgroup CPU throttle** (CPU).
- Colocación: `nodeSelector`, `nodeAffinity`, `podAffinity`, `podAntiAffinity`, `topologySpreadConstraints`.
- **Taints/tolerations** y su diferencia conceptual con affinity.
- **PriorityClass** y preemption de Pods de baja prioridad.
- **PodDisruptionBudget**: proteger disponibilidad durante disruption *voluntaria*.
- **Dynamic Resource Allocation (DRA)** y `ResourceClaim` para GPUs (visión general).

Lo que **no** cubre (se verá después):

- Horizontal/Vertical Pod Autoscaler → `k8s-13`.
- Probes y preStop → `k8s-10`.
- Cluster Autoscaler/Karpenter → `k8s-13`.

## Materiales

- **`theory/lesson.md`** — 12 secciones de teoría profunda.
- **`examples/`**:
  - `01-requests-limits-and-qos/` — tres Pods que materializan `Guaranteed`, `Burstable` y `BestEffort`.
  - `02-anti-affinity-across-zones/` — Deployment con `podAntiAffinity` por `topology.kubernetes.io/zone`.
  - `03-pdb-minavailable/` — PDB con `minAvailable: 2` demostrado contra `kubectl drain`.
- **`activities/`**:
  - `01-tune-resources-and-measure/` (guided-lab) — ajustar requests/limits y clasificar la QoS resultante.
  - `02-protect-rollout-with-pdb/` (independent) — añadir anti-afinidad por nodo y un PDB que haga que `drain` espere, no mate.
- **`resources/links.md`** — documentación oficial y lecturas complementarias.

## Temas y subtemas

1. **Requests y limits**
   - Unidades: `m` (milicores), binarias (`Mi`, `Gi`) vs decimales (`M`, `G`).
   - `requests` como insumo del scheduler (reservan capacidad lógica).
   - `limits` como techo *enforced* por cgroups.
   - `ephemeral-storage` (menos conocido, protege el nodo).
2. **QoS classes**
   - Reglas exactas: `Guaranteed` ↔ requests == limits en todos los contenedores.
   - `Burstable` ↔ hay requests pero no cumple Guaranteed.
   - `BestEffort` ↔ sin requests ni limits en ningún contenedor.
   - Impacto en orden de **eviction** cuando el nodo tiene presión.
3. **OOMKill vs CPU throttling**
   - Límite de memoria superado → el kernel mata el proceso (SIGKILL, `OOMKilled`).
   - Límite de CPU superado → cgroup *throttle* (nunca mata), latencia sube.
   - Cómo diferenciarlos por síntomas y por métricas.
4. **nodeSelector y nodeAffinity**
   - `nodeSelector`: match de labels, duro, sin expresividad.
   - `nodeAffinity`: `requiredDuringSchedulingIgnoredDuringExecution` vs `preferredDuringScheduling...`.
   - Operadores (`In`, `NotIn`, `Exists`, `Gt`, `Lt`).
5. **podAffinity y podAntiAffinity**
   - "Colocar cerca de" vs "lejos de" otro Pod.
   - `topologyKey` como *con qué granularidad* (`hostname`, `zone`, `region`).
   - Costo computacional del scheduler → preferir `preferred` cuando sea posible.
6. **Taints y tolerations**
   - Taint = atributo del *nodo* que repele Pods.
   - Toleration = permiso del *Pod* para aceptar un taint.
   - `effect`: `NoSchedule`, `PreferNoSchedule`, `NoExecute`.
   - Caso típico: nodos GPU, nodos spot, drenaje.
7. **PriorityClass y preemption**
   - Define prioridad numérica (`value: 1000000`).
   - Scheduler puede *desalojar* Pods de menor prioridad para hacer sitio.
   - `preemptionPolicy: PreemptLowerPriority` vs `Never`.
8. **PodDisruptionBudget (PDB)**
   - Protege ante **disrupción voluntaria** (drains, upgrades) — no ante crashes.
   - `minAvailable` o `maxUnavailable` (uno u otro).
   - Interacción con `kubectl drain` y con los autoscalers.
9. **topologySpreadConstraints**
   - Reparte Pods *proporcionalmente* por una topología.
   - `maxSkew`, `topologyKey`, `whenUnsatisfiable` (`DoNotSchedule` | `ScheduleAnyway`).
   - Alternativa más limpia que `podAntiAffinity` en N ≥ 3.
10. **Dynamic Resource Allocation (DRA)**
    - `ResourceClaim`, `DeviceClass`, `ResourceClaimTemplate`.
    - Pensado para GPUs, FPGAs, dispositivos exóticos.
    - Estado y madurez por versión (verificar en Fase 4).

## Conceptos internos (fundamentos)

- Los `requests` son **lógicos**: el scheduler suma `requests` por nodo y rechaza Pods que no quepan. No se "miden" contra el uso real. Un nodo con `requests` sumadas al 100 % puede tener el CPU al 2 %.
- Los `limits` son **físicos** vía cgroups. Para memoria, el kernel aplica `memory.max` (cgroup v2) o `memory.limit_in_bytes` (v1). Al excederlo, el **OOM killer** elige una víctima dentro del cgroup. Para CPU, aplica `cpu.max` (cuota + periodo). No mata: *throttle*.
- La clase `Guaranteed` exige **requests == limits para memoria y CPU en TODOS los contenedores** (incluidos initContainers no-sidecar, con matices). Un Pod `Guaranteed` recibe el `oom_score_adj` más bajo del nodo: es el último candidato a ser matado por presión del nodo.
- `BestEffort` recibe `oom_score_adj` alto: el kernel lo mata primero bajo presión. `Burstable` queda en el medio.
- `kubectl drain` **respeta PDBs** y respeta tolerations: si drenar un nodo violaría un PDB, `drain` **espera** (o falla con `--disable-eviction` desactivado — por default usa el *eviction API* que honra PDB).
- `podAntiAffinity` con `requiredDuringScheduling...` puede dejar Pods en `Pending` si no hay nodos que cumplan la topología. En clusters pequeños, suele ser mejor usar `preferred` o `topologySpreadConstraints`.
- `taint` con `NoExecute` **también desaloja Pods ya corriendo** que no toleran, pasado `tolerationSeconds` (si está definido en la toleration). Útil para desalojo controlado.
- `PriorityClass` con preemption puede matar Pods de menor prioridad para hacer sitio: útil para batch vs online, peligroso si no está diseñado.
- Un PDB con `minAvailable: 2` sobre un Deployment de 3 réplicas permite perder una (durante un drain) pero bloquea perder dos simultáneamente.

## Competencias

- **Conceptual:** explicar por qué un contenedor con memoria limitada fue "OOMKilled" en vez de "throttled", y viceversa para CPU.
- **Operativa:** declarar requests/limits realistas basados en observación; aplicar PDB; ejecutar y leer `kubectl drain` sin tumbar un servicio crítico.
- **Arquitectónica:** elegir entre `podAntiAffinity` y `topologySpreadConstraints`; decidir cuándo introducir `PriorityClass`; diseñar colocación por AZ sin pintarse al rincón del "siempre Pending".

## Ejemplos

- [`examples/01-requests-limits-and-qos/`](examples/01-requests-limits-and-qos/README.md)
- [`examples/02-anti-affinity-across-zones/`](examples/02-anti-affinity-across-zones/README.md)
- [`examples/03-pdb-minavailable/`](examples/03-pdb-minavailable/README.md)

## Actividades

- [`activities/01-tune-resources-and-measure/`](activities/01-tune-resources-and-measure/README.md) — guided-lab.
- [`activities/02-protect-rollout-with-pdb/`](activities/02-protect-rollout-with-pdb/README.md) — independent.

## Entregables

- Un Deployment "crítico" (3 réplicas) con:
  - `requests` y `limits` declarados y justificados.
  - `podAntiAffinity` o `topologySpreadConstraints` por `topology.kubernetes.io/zone`.
  - `PodDisruptionBudget` con `minAvailable: 2`.
- Evidencia textual de un `kubectl drain` que respeta el PDB (bloquea o espera).
- Nota de clasificación de QoS para cada contenedor del entregable.

## Criterios de evaluación

- **Conceptual:** dados tres síntomas (contenedor killed con `Reason: OOMKilled`; latencia P99 subida sin crashes; `kubectl top` mostrando CPU al 100 %), identificar cuál es OOM, cuál throttling, y proponer el ajuste de spec correcto.
- **Operativa:** demostrar en cluster local que `drain` no reduce las réplicas disponibles por debajo del `minAvailable`.
- **Arquitectónica:** elegir entre `podAntiAffinity` (hostname) y `topologySpreadConstraints` (zone) para un cluster de 3 workers y 2 zones, y defender la elección.

## Recursos

Ver [`resources/links.md`](resources/links.md).
