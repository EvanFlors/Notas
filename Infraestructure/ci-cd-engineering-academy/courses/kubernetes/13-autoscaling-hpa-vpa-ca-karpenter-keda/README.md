# k8s-13 — Autoscaling: HPA, VPA, CA, Karpenter, KEDA

## Identificación

- **ID:** `k8s-13-autoscaling-hpa-vpa-ca-karpenter-keda`
- **Curso:** `kubernetes`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `k8s-09-scheduling-resources-affinity-taints-pdb` (requests, limits, QoS, PDB). Recomendable `k8s-10` (probes) y familiaridad con Prometheus.

## Objetivo

Escalar workloads y nodos **con criterio**: elegir la métrica correcta, el controlador correcto, y evitar oscilaciones. Al terminar sabes diseñar un plan de autoscaling para un workload con tráfico diurno, defender por qué eliges HPA + Karpenter frente a VPA + Cluster Autoscaler, y operar KEDA cuando la carga es event-driven.

## Alcance

Este módulo cubre:

- **metrics-server** como fuente de *resource metrics* para HPA/VPA.
- **HPA** con CPU, memoria, **custom metrics** y **external metrics** (Prometheus Adapter, KEDA).
- **VPA** (recomendación vs actualización, modos `Off` / `Initial` / `Recreate` / `Auto`).
- **Cluster Autoscaler (CA)** y su modelo *Pods Pending → ASG scale*.
- **Karpenter**: *scheduler-driven provisioner*, consolidación, diversidad de instance types/AMIs, por qué es más eficiente que CA en AWS.
- **KEDA**: autoscaling event-driven (SQS, Pub/Sub, Kafka, Prometheus, cron), **scale-to-zero**.
- **Interacción HPA ↔ VPA** (no deben compartir la misma métrica).
- Hints de **predictive scaling** (KEDA predictkube, cronScaler).

No cubre (se trata aparte):

- Observabilidad del cluster (Prometheus Operator) → `k8s-15`.
- Operadores y CRDs (teoría) → `k8s-14`.
- FinOps (OpenCost) → `k8s-17`.

## Materiales

- **`theory/lesson.md`** — lección profunda en 12 secciones.
- **`examples/`**:
  - `01-hpa-on-cpu-and-custom-metric/` — HPA v2 sobre CPU + métrica custom de Prometheus; walkthrough comentado.
  - `02-karpenter-provisioner/` — `NodePool` + `EC2NodeClass` de Karpenter v1, consolidación, explicación.
  - `03-keda-scale-from-queue/` — `ScaledObject` leyendo largo de cola (AWS SQS) y scale-to-zero.
- **`activities/`**:
  - `01-hpa-with-prometheus-adapter/` — guided-lab. Instalar `metrics-server` en kind, aplicar HPA, generar carga, validar que escala.
  - `02-karpenter-vs-cas-adr/` — independiente. ADR comparando Karpenter y Cluster Autoscaler para un cluster EKS hipotético.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la cadena *métrica → decisión HPA → replica count* y *Pod Pending → decisión CA/Karpenter → nodo*. Diferenciar `resource` / `pods` / `object` / `external` metrics en HPAv2. Describir los 4 modos de VPA. Justificar por qué HPA y VPA no deben pelearse por la misma señal. |
| Operativa | Instalar `metrics-server` en kind, crear un HPA, generar carga y leer `kubectl describe hpa` sin confundir *current* vs *desired*. Diagnosticar oscilaciones ajustando `behavior.scaleDown.stabilizationWindowSeconds`. Leer eventos de Karpenter y de CA. |
| Arquitectónica | Diseñar un plan de autoscaling para un workload diurno (p. ej. API con pico 09:00–18:00): elegir métrica (RPS vs CPU), buffer, min/max replicas, estrategia de nodos (CA + spot ASG vs Karpenter con `consolidationPolicy: WhenEmptyOrUnderutilized`). |

## Criterios de evaluación

- **Conceptual**: dado un gráfico de latencia, defender si el cuello de botella es CPU, memoria, I/O o concurrencia; proponer la métrica adecuada para HPA.
- **Operativa**: HPA escalando a > 1 réplica bajo carga sintética en cluster local (actividad 01 valida esto automáticamente).
- **Arquitectónica**: ADR Karpenter vs CA para EKS (actividad 02) con decisión defendida, trade-offs y plan de rollback.

## Entregables

- Manifests versionados de HPA + (en EKS/GKE real) Karpenter `NodePool` activo y verificable.
- Writeup del plan de autoscaling diurno con números.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero.
2. Reproduce `examples/01-hpa-on-cpu-and-custom-metric/` leyendo cada manifest.
3. Ejecuta `activities/01-hpa-with-prometheus-adapter/` en kind.
4. Revisa `examples/02-karpenter-provisioner/` y `examples/03-keda-scale-from-queue/` como lectura guiada (no corren en kind).
5. Entrega `activities/02-karpenter-vs-cas-adr/`.

## Siguiente

→ `k8s-14-operators-and-crds`: extender el API con CRDs y escribir un controller mínimo.
