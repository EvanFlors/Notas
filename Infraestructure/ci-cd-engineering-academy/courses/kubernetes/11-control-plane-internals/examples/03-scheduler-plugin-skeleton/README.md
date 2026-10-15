# Ejemplo 03 — Esqueleto del scheduling framework

## Concepto que demuestra

El `kube-scheduler` es **un bucle de plugins**. Entender sus extension points y qué hace cada plugin built-in te permite:

- Leer `kubectl describe pod` sobre un Pod `Pending` y mapear el mensaje de error al plugin que lo emitió.
- Configurar múltiples **scheduler profiles** por nombre, para distintas cargas.
- Decidir si *necesitas* un plugin custom o te alcanza con los built-in + afinidades.

Este ejemplo es **conceptual** (no ejecutable). No vas a compilar un scheduler. Vas a leer cómo está estructurado y mapear mensajes reales a plugins.

## Extension points en orden

```
┌─────────────────────────────────────────────────────────────────────┐
│  QueueSort        (ordena la cola de Pods pendientes)               │
│  PreFilter        (precondiciones; puede abortar sin filtrar)       │
│  Filter           (descarta nodos que no cumplen; "predicate")      │
│  PostFilter       (si NINGÚN nodo pasó: ¿preemption?)               │
│  PreScore         (preparación para scoring)                        │
│  Score            (asigna score 0..100 a cada nodo que pasó Filter) │
│  NormalizeScore   (reescala para que todos los plugins pesen igual) │
│  Reserve          (reserva recursos tentativamente en el nodo)      │
│  Permit           (puede retrasar bind: útil para co-scheduling)    │
│  PreBind          (preparación: p.ej. attach de volumen CSI)        │
│  Bind             (PATCH pod.spec.nodeName = nodo elegido)          │
│  PostBind         (hooks post-decisión; sin efecto en la decisión)  │
└─────────────────────────────────────────────────────────────────────┘
```

## Plugins built-in (los que te vas a encontrar)

| Plugin | Extension points | Qué hace | Mensaje típico en events |
|--------|------------------|----------|--------------------------|
| `NodeName` | Filter | Si Pod tiene `spec.nodeName`, salta scheduling | n/a |
| `NodeUnschedulable` | Filter | Descarta nodos con `spec.unschedulable: true` (cordoned) | `node(s) were unschedulable` |
| `NodeAffinity` | Filter, Score | Respeta `nodeSelector` y `nodeAffinity` | `node(s) didn't match Pod's node affinity/selector` |
| `TaintToleration` | Filter, Score | Descarta nodos con taints no tolerados | `node(s) had untolerated taint {key: value}` |
| `NodeResourcesFit` | PreFilter, Filter, Score | CPU/memoria/ephemeral-storage/pods | `Insufficient cpu`, `Insufficient memory` |
| `NodePorts` | PreFilter, Filter | hostPort libre en el nodo | `node(s) didn't have free ports` |
| `VolumeBinding` | PreFilter, Filter, Reserve, PreBind | PVCs: puede esperar o aprovisionar | `pod has unbound immediate PersistentVolumeClaims` |
| `VolumeRestrictions` | Filter | Volúmenes exclusivos (EBS, singleWriter) | `node(s) had volume node affinity conflict` |
| `InterPodAffinity` | PreFilter, Filter, Score | `podAffinity` / `podAntiAffinity` | `node(s) didn't match pod affinity rules` |
| `PodTopologySpread` | PreFilter, Filter, Score | `topologySpreadConstraints` | `node(s) didn't match pod topology spread constraints` |
| `ImageLocality` | Score | Prefiere nodos que ya tienen la imagen | n/a (solo score) |
| `DefaultPreemption` | PostFilter | Si no cupo, elige víctimas de menor PriorityClass para desalojar | `preemption: 0/N nodes are available` |

## Mapear "mi Pod está Pending" a plugins

Un `kubectl describe pod` sobre un Pod `Pending` termina típicamente con un **Event** del scheduler:

```
Warning  FailedScheduling   30s  default-scheduler
0/3 nodes are available:
  2 node(s) didn't match Pod's node affinity/selector,
  1 node(s) had untolerated taint {role: control-plane}.
preemption: 0/3 nodes are available:
  3 Preemption is not helpful for scheduling.
```

Mapeo directo:

- "didn't match Pod's node affinity/selector" → `NodeAffinity` filter plugin.
- "had untolerated taint" → `TaintToleration` filter plugin.
- "Preemption is not helpful" → `DefaultPreemption` postFilter plugin (intentó desalojar pero ninguna víctima liberaría recursos útiles).

## Scheduler profiles

Un `KubeSchedulerConfiguration` v1 (fragmento):

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: default-scheduler
    plugins:
      score:
        disabled:
          - name: NodeResourcesBalancedAllocation
        enabled:
          - name: NodeResourcesFit
            weight: 10
          - name: ImageLocality
            weight: 2
  - schedulerName: batch-scheduler
    plugins:
      filter:
        enabled: [ { name: GpuAwareFilter } ]
```

Los Pods pueden escoger profile con `spec.schedulerName: batch-scheduler`.

## Plugin out-of-tree (concepto, sin código)

Un plugin custom implementa interfaces Go de `k8s.io/kubernetes/pkg/scheduler/framework`:

```go
// Pseudocódigo. En real: un paquete Go compilado dentro de tu scheduler.
type GpuAwareFilter struct{ handle framework.Handle }

func (p *GpuAwareFilter) Name() string { return "GpuAwareFilter" }

func (p *GpuAwareFilter) Filter(
    ctx context.Context,
    state *framework.CycleState,
    pod *corev1.Pod,
    nodeInfo *framework.NodeInfo,
) *framework.Status {
    needs := pod.Annotations["gpu.required"] == "true"
    has   := nodeHasGPU(nodeInfo.Node())
    if needs && !has {
        return framework.NewStatus(framework.UnschedulableAndUnresolvable,
            "node has no GPU")
    }
    return framework.NewStatus(framework.Success)
}
```

Se compila con `main.go` que llama a `app.NewSchedulerCommand(app.WithPlugin("GpuAwareFilter", NewGpuAwareFilter))`, se empaqueta en una imagen y se despliega como un **segundo scheduler** (`schedulerName: batch-scheduler`). Nunca se "reemplaza" al default — se añaden profiles.

## Lo que deberías notar

- El scheduler **no es monolítico**: es una secuencia de plugins pequeños que puedes activar/desactivar.
- Casi cualquier mensaje de `FailedScheduling` es trazable a **un plugin específico**.
- Para la mayoría de casos reales (afinidad, taints, resources, topology spread) **no necesitas** un plugin custom. El 95% del tuning es ajustar `requests`, `tolerations`, `topologySpreadConstraints` y PodDisruptionBudgets.
- Los **extenders** HTTP viejos están deprecados. Si alguien te propone usarlos en 2026, es señal de código legado.
