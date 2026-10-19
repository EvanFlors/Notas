# aws-12 — Observabilidad en AWS: CloudWatch, X-Ray y CloudTrail

## Identificación

- **ID:** `aws-12-observability-cloudwatch-xray-cloudtrail`
- **Curso:** `aws`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `aws-04` (IAM/VPC básicos), `aws-10` (ECS/EKS). Idealmente también `opentelemetry-01..08` para hablar con autoridad de ADOT.

## Objetivo

Instrumentar **observabilidad nativa de AWS** y conectarla al stack OSS del programa (Prometheus/Grafana/Tempo/Loki). Al terminar deberías poder:

- Diseñar una política de **retención y filtrado** para CloudWatch Logs que recorte el gasto sin perder la señal útil.
- Crear **alarmas** CloudWatch (static y anomaly detection) y decidir cuándo usar **composite alarms**.
- Instrumentar una app con **OpenTelemetry** emitiendo a **ADOT Collector** → CloudWatch *y* Prometheus/Tempo en paralelo.
- Justificar por qué **CloudTrail** debe estar activo en toda cuenta y qué eventos cuestan dinero (**data events**) frente a los que son gratis (**management events**).

## Alcance

Este módulo cubre:

- **CloudWatch Logs**: log groups, retention, subscription filters, **metric filters**, **Logs Insights**. Por qué no sustituye a Loki/ELK en volúmenes grandes (ingestión + storage).
- **CloudWatch Metrics**: namespaces, dimensions, resolución (standard vs high-resolution), **custom metrics** vía PutMetricData o EMF.
- **CloudWatch Alarms**: static threshold vs **anomaly detection**; **composite alarms** para reducir ruido; estado `INSUFFICIENT_DATA` como alarma por derecho propio.
- **CloudWatch Container Insights** para ECS/EKS (métricas de clúster, nodos, pods).
- **X-Ray**: trazas, segments, subsegments, sampling rules; relación con **OpenTelemetry** vía **ADOT** (AWS Distro for OpenTelemetry).
- **CloudTrail**: management events (gratis, imprescindibles), **data events** (coste real: S3 object-level, Lambda invoke), **CloudTrail Insights** (anomalías de API).
- **CloudWatch Agent vs ADOT Collector**: cuándo cada uno; por qué ADOT es un distro empaquetado del OTel Collector contrib con receivers/exporters AWS listos.

Lo que **no** cubre:

- Backends OSS en profundidad (ver cursos `prometheus-grafana` y `opentelemetry`).
- Observabilidad de red/VPC: VPC Flow Logs se mencionan de pasada; el módulo foco es la app.
- SIEM corporativo (Security Lake, Security Hub) — es tema de `aws-16-devsecops-on-aws`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones: señales en AWS, modelo de costes, EMF, ADOT, CloudTrail y por qué siempre on.
- **`examples/`** — ejemplos demostrativos (lectura y análisis):
  - `01-cloudwatch-logs-insights/` — recorrido por queries Logs Insights útiles y por qué son caras.
  - `02-adot-collector-eks/` — manifiesto del ADOT Collector como DaemonSet en EKS con pipelines a CloudWatch y a Prometheus Remote Write.
  - `03-cloudtrail-org-trail/` — por qué un **organization trail** encripta mejor la postura de auditoría; estructura típica de un evento JSON de CloudTrail.
- **`activities/`** — dos actividades **independientes**:
  - `01-instrument-fastapi-with-adot/` — escribir una `config.yaml` de ADOT Collector que acepta OTLP y exporta a `awsxray`, `awsemf` y `prometheusremotewrite` simultáneamente. Validación estructural + opcional smoke con LocalStack para CloudWatch Logs.
  - `02-cost-trim-cw-logs/` — producir un plan de retención por tier, un **metric filter** JSON, una query **Logs Insights** y una **alarma** CloudWatch, todo validado estructuralmente.
- **`resources/links.md`** — documentación oficial AWS, ADOT y comparativas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una frase la diferencia entre **CloudWatch Agent** y **ADOT Collector**. Nombrar los 3 niveles de evento de CloudTrail (management/data/insights) y su coste relativo. |
| Operativa | Escribir un **metric filter** y una query de **Logs Insights** sin consultar la documentación. Diseñar una **alarma** con `datapoints to alarm` y `treat missing data` justificados. |
| Arquitectónica | Decidir cuándo usar **EMF** (métricas desde logs) frente a `PutMetricData`. Justificar un pipeline ADOT que entrega a CloudWatch y a Prometheus a la vez (dual-write durante migración). |

## Criterios de evaluación

- Explica por qué **CloudTrail management events** son prácticamente gratis y **data events** no.
- Diseña una política de retención por tier (hot/warm/cold) y la aterriza en `retention_in_days` concretos.
- Dado un `config.yaml` ADOT, identifica receivers, processors y exporters y a qué servicio AWS/OSS va cada signal.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- `config.yaml` de ADOT Collector multi-exporter (actividad 01).
- Plan de retención + metric filter + Logs Insights query + alarma CloudWatch (actividad 02).

## Costes reales

**Cero.** Todas las validaciones son estructurales (JSON/YAML/regex) o usan **LocalStack** opcional para CloudWatch Logs. No se consume cuota real de AWS en ningún script.

## Siguiente módulo

→ `aws-13-edge-dns-cdn-acm` — Route 53, ACM, CloudFront para publicar el workload al mundo.
