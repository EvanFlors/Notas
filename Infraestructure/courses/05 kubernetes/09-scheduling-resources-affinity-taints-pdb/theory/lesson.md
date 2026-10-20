# k8s-09 — Lección: scheduling, recursos, afinidad, taints y PDB

> **Idea única:** el scheduler no "mide" tus Pods; le declaras lo que esperas (`requests`) y lo que como máximo tolera (`limits`), y la combinación decide **dónde** corren, **cómo compiten** por recursos del nodo y **quién sobrevive** bajo presión.

Trabaja con un cluster local (kind) con 3 workers. El `examples/02-anti-affinity-across-zones/kind-3-workers.yaml` lo levanta.

## 1. Panorama: tres preguntas que resuelve este módulo

Un Pod pasa por **tres etapas de decisiones** antes de servir tráfico útil:

1. **Scheduling** — ¿en qué nodo corre? Depende de `requests`, `nodeSelector`, affinity, taints, topology spread.
2. **Runtime** — ¿cuántos recursos puede usar sin molestar al vecino? Depende de `limits` (via cgroups del kernel).
3. **Disrupción** — ¿quién muere cuando el nodo se queda sin memoria o cuando el operador drena? Depende de la QoS y del PDB.

Si confundes las tres, acabas con Pods `Pending` eternos, OOMKills misteriosos y rollouts que tumban producción. La buena noticia: cada una se controla con primitivas pequeñas y combinables.

## 2. Requests y limits: unidades, significado, ergonomía

Un `container.resources` se ve así:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
    ephemeral-storage: 1Gi
  limits:
    cpu: 500m
    memory: 512Mi
    ephemeral-storage: 2Gi
```

Reglas:

- **CPU** se mide en *cores*. `1 = 1 core`. `500m = 0.5 core = 500 milicores`.
- **Memoria** y **ephemeral-storage**: usa unidades **binarias** (`Mi`, `Gi`), no decimales (`M`, `G`). Son más predecibles. 1 GiB = 1024 MiB; 1 GB = 1000 MB.
- **`requests`** = lo que el **scheduler** reserva. Suma de requests por nodo ≤ capacidad asignable del nodo. Si no cabe → `Pending`.
- **`limits`** = techo *enforced* por **cgroups**. Lo discutimos en §4.
- **`ephemeral-storage`** = disco temporal del nodo (emptyDir, logs). Si lo omites, un contenedor con fuga de logs puede llenar `/var/lib/kubelet` y el nodo cae en `DiskPressure`.

**Ergonomía:** limitar la memoria es casi siempre buena idea. Limitar la CPU no siempre: ver §4 sobre *throttling*.

## 3. QoS classes: cómo K8s te clasifica

Kubernetes **deriva** la QoS del Pod a partir de los `resources` de cada contenedor. No la declaras tú.

| Clase | Regla |
|-------|-------|
| **Guaranteed** | Para todos los contenedores: `requests.cpu == limits.cpu` **y** `requests.memory == limits.memory`, ambos presentes. |
| **Burstable** | Al menos un contenedor tiene `requests` o `limits`, pero no cumple Guaranteed. |
| **BestEffort** | Ningún contenedor declara `requests` ni `limits`. |

Mira la clase con:

```bash
kubectl get pod <name> -o jsonpath='{.status.qosClass}{"\n"}'
```

Importa porque bajo **presión del nodo** (memoria baja, disco, PIDs), el **kubelet desaloja** Pods en este orden: `BestEffort` primero, luego `Burstable` que exceden sus `requests`, y por último `Guaranteed`. Además, cuando el **OOM killer del kernel** actúa dentro del nodo, usa `oom_score_adj`: `Guaranteed` recibe el valor más bajo (menos probable víctima), `BestEffort` el más alto.

## 4. OOMKill vs CPU throttling (la pregunta de examen)

**Memoria** y **CPU** se comportan radicalmente distinto bajo límite.

### Memoria: límite excedido → OOMKill

El cgroup del contenedor tiene `memory.max`. Si un proceso dentro pide más y el kernel no puede recuperar páginas, dispara el **OOM killer**: envía `SIGKILL` (no `SIGTERM`, no hay chance de limpiar) al proceso con mayor `oom_score`. El contenedor termina con:

```
State:          Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

(`137 = 128 + 9`; 9 = SIGKILL.)

Síntomas: `kubectl describe pod` muestra `OOMKilled`; `kubectl get events` muestra `OOMKilling`; el contador `container_oom_events_total` sube.

### CPU: límite excedido → throttle, no kill

El cgroup tiene `cpu.max = <cuota> <periodo>` (típicamente `50000 100000` = 500m). Si el proceso quiere más, el kernel simplemente **no lo despacha** hasta el próximo periodo. **Nunca lo mata**. El síntoma es **latencia**: P99 sube, requests encoladas, `nr_throttled` del cgroup incrementa.

Métricas útiles (con cAdvisor/kube-prometheus):

- `container_cpu_cfs_throttled_periods_total` / `container_cpu_cfs_periods_total` → ratio de throttling.
- `container_memory_working_set_bytes` cerca de `kube_pod_container_resource_limits{resource="memory"}` → predice OOM.

### Diagnóstico por síntomas

| Síntoma | Culpable probable | Acción |
|---------|-------------------|--------|
| `Reason: OOMKilled`, `ExitCode: 137`, pod reiniciado | Memory limit excedido | Subir `limits.memory` o investigar leak |
| Pod vivo, latencia alta, CPU al 100 % en el nodo | CPU throttling | Subir `limits.cpu` o quitar el limit |
| Pod `Pending`, `Insufficient cpu` en events | `requests.cpu` no cabe en ningún nodo | Bajar `requests` o añadir capacidad |
| Pod killed con `Reason: Error`, exit code variable | **No** es OOM; buscar en logs | Revisar app, no recursos |

**Debate honesto:** muchos equipos de producción **omiten `limits.cpu`** por el throttling (y mantienen `requests.cpu`). La memoria sí la limitan siempre. Es una elección válida si entiendes qué cedes (vecinos ruidosos).

## 5. `nodeSelector` y `nodeAffinity`

`nodeSelector` es la forma más vieja y simple:

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

Match exacto sobre labels del nodo. Si ningún nodo lo tiene → `Pending`.

`nodeAffinity` es más expresivo y tiene dos sabores:

- `requiredDuringSchedulingIgnoredDuringExecution` — duro al schedulear; si el nodo pierde el label después, el Pod sigue corriendo.
- `preferredDuringSchedulingIgnoredDuringExecution` — blando, puntuación; schedulea donde pueda si no hay match.

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["us-east-1a", "us-east-1b"]
```

Operadores: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.

## 6. `podAffinity` y `podAntiAffinity`

Decisiones **relativas a otros Pods**, no al nodo.

- **podAffinity**: "colócame cerca de Pods con tal label". Útil para co-locar un cache junto a su app.
- **podAntiAffinity**: "no me pongas donde haya otro Pod con tal label". Útil para dispersar réplicas.

Clave: **`topologyKey`** define *con qué granularidad* medimos "cerca" o "lejos":

- `kubernetes.io/hostname` → por nodo.
- `topology.kubernetes.io/zone` → por AZ.
- `topology.kubernetes.io/region` → por región.

Ejemplo (anti-affinity por zona, requerido):

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: payments
      topologyKey: topology.kubernetes.io/zone
```

**Costo:** evaluar affinity de Pod es O(N·M) en el scheduler; en clusters de miles de nodos, `required` puede ser caro. Preferir `preferred` o `topologySpreadConstraints` cuando se pueda.

## 7. Taints y tolerations

Taint = atributo del *nodo* que **repele** Pods. Toleration = permiso del *Pod* para aceptar un taint. Son opuestos complementarios de affinity.

```bash
kubectl taint nodes gpu-node-1 nvidia.com/gpu=true:NoSchedule
```

```yaml
tolerations:
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
```

`effect`:

- `NoSchedule` — no se admiten nuevos Pods sin toleration.
- `PreferNoSchedule` — scheduler intenta evitarlo pero puede si no hay otra.
- `NoExecute` — **expulsa Pods ya corriendo** sin toleration (con `tolerationSeconds` opcional).

**Casos típicos:**

- Nodos GPU: taint específico; solo los workloads que lo toleran aterrizan ahí (y el precio por hora baja para el resto).
- Nodos spot/preemptibles: taint `node.kubernetes.io/preemptible` para que solo cargas tolerantes a reinicio aterricen.
- `kubectl drain` añade internamente taint `NoExecute` para expulsar.

Diferencia conceptual con affinity: **affinity es atracción; taint es rechazo**. Suelen combinarse: taint `gpu=true:NoSchedule` + nodeAffinity del Pod `gpu=true` = solo Pods GPU en nodos GPU, y nadie más.

## 8. `PriorityClass` y preemption

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-online
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Workloads online críticos (checkout, auth)."
```

Un Pod referencia la clase con `spec.priorityClassName`. Si el scheduler no encuentra sitio para él, intenta **preempt**: desaloja Pods de **menor prioridad** para hacer hueco.

Gotchas:

- Preemption respeta PDBs; si desalojar violaría un PDB, salta al siguiente candidato.
- `preemptionPolicy: Never` → el Pod puede tener prioridad alta para la cola, sin desalojar a nadie.
- Dos clases ya vienen: `system-cluster-critical` y `system-node-critical`. **No las uses para apps de usuario.**

## 9. `PodDisruptionBudget` (PDB)

Un PDB **limita la disrupción voluntaria**. Es un contrato que dice: "en cualquier momento, al menos N (o como máximo N) réplicas deben estar disponibles".

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: payments-pdb
spec:
  minAvailable: 2        # o maxUnavailable: 1 (uno u otro, no ambos)
  selector:
    matchLabels:
      app: payments
```

**Qué protege (voluntario):**

- `kubectl drain` de un nodo.
- Upgrades del cluster (cloud provider dreando nodos).
- Autoscalers (Cluster Autoscaler/Karpenter) consolidando nodos.

**Qué NO protege (involuntario):**

- Un crash de la app.
- Un kernel panic del nodo.
- Un OOMKill.
- Eviction por `NodePressure`.

Mecanismo: el **Eviction API** (`POST /pods/<name>/eviction`) consulta el PDB antes de permitir la evicción. Si violaría el budget, responde `429 Too Many Requests`. `kubectl drain` usa el eviction API por default → **respeta el PDB**.

**Trampa común:** `minAvailable: 100%` con un Deployment de 1 réplica **bloquea cualquier drain**. Usa `minAvailable: N` o `maxUnavailable: N` con N menor que el total de réplicas, y asegúrate de que el Deployment realmente tiene N+1 pods disponibles.

## 10. `topologySpreadConstraints`

Alternativa moderna a `podAntiAffinity` para **repartir** Pods proporcionalmente por una topología:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: payments
```

Lee: "para los Pods con label `app=payments`, la diferencia entre la zona con más y la con menos no debe exceder 1. Si no se puede, no schedulees (duro)."

Comparado con `podAntiAffinity`:

- Mejor para N ≥ 3 réplicas en 2-3 zonas: anti-affinity "no co-ubiques" fuerza 1 por zona; spread "reparte parejo" tolera 2+2+1 en 3 zonas con 5 réplicas.
- `whenUnsatisfiable: ScheduleAnyway` evita el `Pending` eterno.
- Semánticamente más clara para "spread even".

## 11. Dynamic Resource Allocation (DRA) para GPUs

DRA es la evolución de "device plugins" (NVIDIA, AMD, etc.). Permite al workload *reclamar* un recurso complejo (una GPU particular, un slice de GPU, un FPGA) y al driver asignarlo *dinámicamente* al nodo correcto.

```yaml
apiVersion: resource.k8s.io/v1alpha3
kind: ResourceClaimTemplate
metadata:
  name: single-gpu
spec:
  spec:
    devices:
      requests:
      - name: gpu
        deviceClassName: nvidia-h100
```

```yaml
apiVersion: v1
kind: Pod
spec:
  resourceClaims:
  - name: gpu
    resourceClaimTemplateName: single-gpu
  containers:
  - name: train
    resources:
      claims:
      - name: gpu
```

Estado por versión: verificar en Fase 4 (en 1.30+ llega como *beta* parcial). Para producción hoy, muchos equipos siguen con `nvidia.com/gpu` del device plugin clásico. Mencionar DRA es importante por dirección: *es* el futuro.

## 12. Cómo trabajar este módulo (orden sugerido y debugging)

Orden:

1. Lee la lección entera una vez.
2. Corre `examples/01` (QoS). Mira `kubectl describe` de cada Pod y confirma la clase.
3. Corre `examples/02` (anti-affinity en kind con 3 workers). Fuerza un escenario de `Pending` quitando un worker.
4. Corre `examples/03` (PDB + drain). Observa `drain` esperar.
5. Haz la actividad 1 (guided-lab de resources).
6. Haz la actividad 2 (independent de PDB + anti-affinity).

**Checklist de debugging rápido:**

- `kubectl describe pod <p>` → sección **Events**: `FailedScheduling`, `Insufficient cpu`, `0/3 nodes available`.
- `kubectl get pod <p> -o jsonpath='{.status.qosClass}'` → QoS real.
- `kubectl get events --sort-by=.lastTimestamp | tail -20` → últimas decisiones del scheduler.
- `kubectl top pod <p>` (requiere metrics-server) → uso vs límite.
- `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` → prueba de PDB.
- Si todo falla: `kubectl get pod <p> -o yaml` y lee el `spec` entero. 80 % de los problemas de scheduling son typos en labels o unidades mal escritas.
