# k8s-15 — Observabilidad en Kubernetes

## Identificación

- **ID:** `k8s-15-observability-in-k8s`
- **Curso:** `kubernetes`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-14-operators-and-crds` (CRDs y patrón operador). Útil: `k8s-11-control-plane-internals` (eventos, kubelet, cAdvisor) y `k8s-09-scheduling-resources-affinity-taints-pdb` (requests/limits para interpretar métricas).

## Objetivo

**Instrumentar observabilidad nativa K8s con stack OSS.** Desplegar y operar `metrics-server` + `kube-state-metrics` + **Prometheus Operator** (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`, `Alertmanager`) + **Grafana** + **Loki** (logs) + **Tempo** (traces) + **OpenTelemetry Operator**. Diseñar **alertas útiles sin ruido** y runbooks disparables desde ellas.

## Alcance

Este módulo cubre:

- **Métricas**: diferencia entre `metrics-server` (resource metrics API para HPA/`kubectl top`) y **Prometheus** (métricas dimensionales de aplicación e infraestructura). `kube-state-metrics` como fuente del estado K8s. `node-exporter` para métricas del host. **cAdvisor** integrado en `kubelet` para métricas de contenedores (CPU, memoria, red, IO).
- **Prometheus Operator**: CRDs `Prometheus`, `Alertmanager`, `ServiceMonitor`, `PodMonitor`, `Probe`, `PrometheusRule`. Chart `kube-prometheus-stack` como paquete integrado.
- **Dashboards**: Grafana + **kubernetes-mixin** (dashboards y alertas probadas publicadas por la comunidad SIG-Instrumentation).
- **Logs**: **Loki** (modelo "índice por labels, no por texto") con **Promtail**, **Vector** o **OTel Collector** como shipper. Patrón DaemonSet por nodo.
- **Traces**: **Tempo** (compatible con OTLP, Jaeger, Zipkin) y comparación con **Jaeger**. **OpenTelemetry Operator** para auto-instrumentación de Pods y despliegue del Collector.
- **Eventos como señal**: `kubectl events`, `EventExporter` para enviar eventos K8s a Loki o Prometheus (contadores derivados).
- **eBPF-based** (introducción): **Pixie** para auto-telemetría sin instrumentar y **Hubble** (Cilium) para observabilidad de red L3-L7.
- **Alerting**: cómo escribir alertas **basadas en SLO** con **multi-window multi-burn-rate**; relación 1 alerta → 1 runbook.

Lo que **no** cubre:

- Instalación de Prometheus standalone sin Operator (ver curso `prometheus-grafana`).
- Pipelines de traces desde la app en profundidad (ver curso `opentelemetry`).
- APM comercial (Datadog, New Relic, Dynatrace).
- Profiling continuo con pyroscope/parca (mención, no práctica).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-prometheus-operator-stack/` — instalar `kube-prometheus-stack` con Helm sobre kind.
  - `02-servicemonitor-for-fastapi/` — endpoint `/metrics` en FastAPI + `ServiceMonitor` que lo scrapea.
  - `03-otel-operator-with-tempo/` — OpenTelemetry Operator + Collector + Tempo backend.
- **`activities/`**:
  - `01-full-oss-observability/` — guided-lab: cluster con Prometheus + Grafana + Loki + Tempo + OTel.
  - `02-tune-alerts-signal-vs-noise/` — independent: reescribir `PrometheusRule` ruidoso a SLO + multi-window.
- **`resources/links.md`**.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `metrics-server` y Prometheus. Distinguir `ServiceMonitor` vs `PodMonitor` vs `Probe`. Explicar por qué una alerta `rate(cpu) > 0.1 for 1m` es basura. Describir SLO + burn-rate multi-ventana. |
| Operativa | Desplegar `kube-prometheus-stack`, agregar un `ServiceMonitor` para una app propia, integrar OTel Collector con Tempo, escribir una `PrometheusRule` SLO-based y asociar un runbook. |
| Arquitectónica | Decidir qué señales merecen alerta, qué va a dashboard, qué va a logs; elegir Loki vs ELK vs cloud-native; elegir Tempo vs Jaeger; dimensionar retention vs costo. |

## Entregables

- Cluster kind o k3d con `kube-prometheus-stack` + Loki + Tempo + OTel Operator desplegados.
- Un `ServiceMonitor` que scrapea una app propia.
- Un `PrometheusRule` **SLO-based + multi-window** reemplazando a uno ruidoso.
- Un **runbook** en Markdown enlazado desde cada alerta por `annotations.runbook_url`.

## Criterios de evaluación

- El cluster expone `/metrics` para `kube-state-metrics`, `node-exporter`, Prometheus y la app.
- Toda alerta activa tiene `annotations.summary`, `annotations.description` y `annotations.runbook_url`.
- Toda alerta usa `for:` apropiado (no `1m` para una señal volátil) **o** multi-window burn-rate.
- No existe en el stack final la alerta `HighCpuUsage` con `rate(cpu) > 0.1 for 1m` (criterio literal: el estudiante debe eliminarla o reemplazarla).
- Hay al menos un dashboard de la mixin `kubernetes-mixin` cargado en Grafana.

## Secuencia recomendada

1. Leer `theory/lesson.md` completa.
2. Reproducir `examples/01-prometheus-operator-stack/` (instalación base).
3. Reproducir `examples/02-servicemonitor-for-fastapi/` (instrumentar algo propio).
4. Reproducir `examples/03-otel-operator-with-tempo/` (traces).
5. Hacer `activities/01-full-oss-observability/` (guiada, stack completo).
6. Hacer `activities/02-tune-alerts-signal-vs-noise/` (independiente, alertas SLO).
7. Escribir dos runbooks como entregable adicional.

## Siguiente

→ `k8s-16-security-hardening-and-supply-chain`: endurecer el cluster que ya tienes observable.
