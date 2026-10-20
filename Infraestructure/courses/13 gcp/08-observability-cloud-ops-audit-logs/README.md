# gcp-08 — Observability con Cloud Operations y Audit Logs

## Identificación

- **ID:** `gcp-08-observability-cloud-ops-audit-logs`
- **Curso:** `gcp`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gcp-04` (Cloud Run), `gcp-07` (GKE), curso `aws` ≥ `aws-12` (observability en AWS para comparar).

## Objetivo

Interiorizar cómo se opera la observabilidad en GCP con **Cloud Operations** (Logging, Monitoring, Trace, Profiler) y cómo se protege la auditoría con **Audit Logs** (Admin Activity + Data Access). Al terminar deberías poder — en papel — diseñar una política de alerta sobre un **SLO**, escribir una **log-based metric**, planificar la **retención y los sinks** de logs para control de costo, y describir cómo una app instrumentada con **OpenTelemetry** envía trazas a **Cloud Trace** vía el **Collector (ADOT/OTel Collector)** sin acoplarse al vendor.

## Alcance

Este módulo cubre:

- **Cloud Logging**: log buckets, retención, sinks a BigQuery/GCS/Pub/Sub, **log-based metrics** (counter y distribution), filtros de exclusión para control de costo.
- **Cloud Monitoring**: metrics scopes multi-project, dashboards, **alerting policies** (condition + notification channel), **SLOs nativos** sobre servicios.
- **Cloud Trace** y **Cloud Profiler**: ingesta de trazas OTLP y profiles continuos.
- **Audit Logs**: Admin Activity (gratis, siempre on), Data Access (opt-in, puede ser caro), System Event, Policy Denied; export a BigQuery para análisis a largo plazo.
- **OpenTelemetry → Cloud Trace** vía Collector (OTel Collector o AWS Distro for OpenTelemetry — ADOT — que es un fork vendor-friendly del upstream): patrón recomendado para no acoplar la app al vendor.
- **FinOps de logs**: exclusion filters en `_Default` bucket, retención por bucket, sinks de "copia barata" a GCS/BigQuery, comparación con CloudWatch.

Lo que **no** cubre:

- Cloud Service Mesh / telemetry basada en Istio → `gcp-07`.
- Security Command Center (findings, detectores) → `gcp-10`.
- DevSecOps + Binary Authorization sobre esta telemetría → `gcp-10`.
- Terraform operativo (`terraform-google-modules/observability`) — se referencia pero el laboratorio real es Fase 4.

Este módulo es **mayoritariamente conceptual + validación estructural de JSON y Markdown**. **No** se provisiona nada en un project real. Las dos actividades son análisis escritos y JSON validados estructuralmente; el único tooling es `bash`, `jq`, `python3` y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — walkthroughs demostrativos (lectura y análisis, no ejecución):
  - `01-otel-to-cloud-trace-adot/` — flujo OTel SDK → Collector (ADOT) → Cloud Trace, con exporter dual a Jaeger para desacoplo.
  - `02-log-analytics-walkthrough/` — convertir un `_Default` bucket a Log Analytics y correr queries SQL sobre logs.
  - `03-audit-log-sink-to-bigquery/` — sink de Admin Activity + Data Access a BigQuery para análisis a 400 días.
- **`activities/`** — dos actividades **independientes**:
  - `01-slo-and-alerting-policy-json/` — diseñar un SLO para `checkout` en Cloud Run y escribir el `alerting-policy.json` + `logs-based-metric.json` + ADR corto justificándolo.
  - `02-cost-trim-logging/` — plan de retención y filtros de exclusión para una org pequeña, con `exclusion-filter.json`, `sink.json` y `LOG-RETENTION-ADR.md`.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar Admin Activity vs Data Access logs; explicar por qué los primeros son gratis y los segundos no; mapear Cloud Logging/Monitoring/Trace a sus equivalentes CloudWatch; explicar SLI/SLO/error budget. |
| Operativa (sin infra) | Escribir una alerting policy JSON válida; escribir una log-based metric; escribir una exclusión; planificar un sink por tipo de log. |
| Arquitectónica | Diseñar la cadena OTel SDK → Collector → Cloud Trace (y a Prometheus/Grafana en paralelo) sin acoplar la app; decidir qué va a Cloud Logging vs BigQuery vs GCS; justificar retención por bucket. |

## Criterios de evaluación

- Dado un `alerting-policy.json`, lee y explica qué métrica dispara, con qué threshold, a qué canal.
- Lee una `logs-based-metric.json` y explica qué patrón de log extrae y qué labels usa.
- Justifica cuándo activar Data Access logs (y cuándo no) para un servicio concreto.
- Diseña la retención de un `_Default` bucket y de un bucket custom para `audit`.
- Dibuja el flujo OTel → Collector → Cloud Trace y describe por qué el Collector es el punto de desacoplo.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `SLO-ADR.md` + `alerting-policy.json` + `logs-based-metric.json` + `README-INTENT.md` (sale de la actividad `01`).
- **ADR** `LOG-RETENTION-ADR.md` + `exclusion-filter.json` + `sink.json` + `README-INTENT.md` (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto y JSON. No se requiere project GCP activo. Si en una fase posterior decides materializarlo:

- **Cloud Logging** `_Required` bucket (Admin Activity, System Event): **gratis**.
- **Cloud Logging** `_Default` bucket: 50 GiB/mes gratis por project; después se cobra por GiB ingerido.
- **Cloud Monitoring** metrics custom: free tier generoso; después por MiB ingerido y por serie temporal activa.
- **Cloud Trace**: 2.5M spans/mes gratis; después por millón.
- **Audit Logs — Data Access**: pueden explotar la factura si los activas en un servicio con mucho tráfico (p. ej. Cloud Storage, BigQuery). Actívalos **selectivamente**.
- **BigQuery (sink destino)**: cobra por almacenamiento + queries; retener 400 días de audit logs puede estar entre pocos y varios USD/mes.

## Siguiente módulo

→ `gcp-09-multi-project-org-cloud-identity` — operar la jerarquía Organization/Folders/Projects con guardrails y SSO.
