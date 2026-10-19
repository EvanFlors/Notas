# Intent — SLO + alerting policy + logs-based metric para checkout-api

Este documento explica **qué hace cada archivo y por qué es necesario**. Lee junto con `SLO-ADR.md`.

## alerting-policy

Alerta de **burn rate rápido** sobre el SLO 99.9%/30d del service `checkout-api`.

- **Condición**: `select_slo_burn_rate(..., "3600s") > 14.4`. Un burn rate de 14.4× sobre una ventana de 1 hora significa "estamos consumiendo 2% del error budget mensual en esos 60 min". Es el umbral canónico del libro SRE para "fast burn".
- **`notificationChannels`**: dos canales — PagerDuty (despierta al oncall) y Slack `#sre` (log público del incidente). Separar los canales por severidad es una decisión del catálogo organizacional; aquí la policy enruta a los dos porque es P1.
- **`documentation`** (campo obligatorio en todas las policies del equipo): lleva runbook inline. Un oncaller a las 3 am no debería tener que googlear qué hacer. Incluye: enlace al dashboard, owner del servicio, 3-4 pasos de triage y la razón por la que esta alerta se disparó (para no leerla como falsa alarma).
- **`alertStrategy.autoClose`**: 30 min. Si la condición deja de cumplirse, auto-cierra para no dejar ruido abierto.

## logs-based-metric

Counter `payment_declined_count`:

- **Filter**: `resource.type="cloud_run_revision" AND resource.labels.service_name="checkout-api" AND jsonPayload.event="payment_declined"`. Scope mínimo necesario — nunca filtros globales que matcheen todo el project.
- **Labels extraídas**: `reason` (razón del decline — card, insufficient funds, fraud) y `app_version`. Permiten slicing en dashboards de negocio sin crear 10 métricas diferentes.
- **Por qué DELTA + INT64**: queremos un contador clásico (cada log suma 1); no es distribution porque no estamos midiendo un valor numérico por evento.
- **Cardinalidad controlada**: `reason` es un enum pequeño (<10 valores); `app_version` es acotado (releases por semana). Si extrajésemos un campo libre (ej. `user_id`), reventaríamos la cuota de series temporales de Monitoring.

## SLO

- **SLI**: ratio `request_count{response_code_class != "5xx"} / request_count`. Decidimos excluir 4xx (fallo del cliente, no del servicio).
- **Goal**: 99.9% — alineado con el SLA interno con negocio.
- **Rolling period**: 30 días. Alineado con reviews mensuales y con el acuerdo. Evita "amnesia" de un incidente grande (que ocurre con ventanas de 7 días).
- **Error budget**: 43m 12s/mes. Alertas de **burn rate** consumen este budget — no métricas crudas.

## Por qué burn rate y por qué documentation obligatoria

- **Burn rate**: alinea alerta con experiencia del usuario y con el budget declarado. Reduce ruido (no todas las picos de 5xx disparan P1) y evita silencio (0.5% sostenido durante 10 días dispara slow-burn aunque no haga pico).
- **documentation obligatoria**: política del equipo de observabilidad. Toda policy sin `documentation.content` falla el PR review. Razón: el coste medio de un oncall mirando una alerta sin contexto es 15-20 min de triage ciego; con runbook inline, 2-3 min.

## Placeholders

- `PROJECT_ID` — se resuelve en Fase 4 por Terraform.
- `SERVICE_ID`, `SLO_ID` — los recursos SLO se crean antes de la policy; sus IDs se inyectan.
- `CHANNEL_ID_PAGERDUTY`, `CHANNEL_ID_SLACK_SRE` — se crean una vez por project y se referencian por ID.

## Qué NO está en estos archivos (y debería estar en Fase 4)

- Dashboard JSON agrupando request_count, latency, payment_declined — fuera de alcance de esta actividad.
- Slow-burn policy (10% en 3d) — extensión opcional en §10 del README.
- Export del SLO a BigQuery para reporting histórico — a decidir con Finance/Product.
