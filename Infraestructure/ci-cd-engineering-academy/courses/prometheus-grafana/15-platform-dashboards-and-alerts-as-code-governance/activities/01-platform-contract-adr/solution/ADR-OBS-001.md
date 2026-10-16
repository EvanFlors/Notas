# ADR-OBS-001 — Platform Observability Contract

## Status

Accepted — 2026-04-02. Supersedes informal "observability guidelines" wiki.

## Context

Hoy la plataforma tiene 180 dashboards sin dueño claro, 400 reglas de alerta de las cuales ~30 % no tienen runbook ni `labels.team`, y una factura mensual de observabilidad que pasó de $4 k a $12 k en seis meses sin explicación. El equipo de plataforma dedica el 40 % de su tiempo a "¿quién puso esta alerta?" y "¿por qué la factura subió?".

Se intentó antes resolverlo con un wiki de buenas prácticas (ignorado) y con revisiones ad-hoc por el equipo de plataforma (bottleneck). Falta un contrato explícito, versionado y revisable, con tests automatizados que lo hagan cumplir.

## Decision

### Labels obligatorios

Toda métrica de aplicación debe incluir:

- `team` — equipo dueño del servicio. Driver del routing de alertas y de permisos en Grafana. Se impone por `external_labels` del Prometheus del namespace y por relabel de scrape; CI falla si una métrica no lo lleva.
- `service` — nombre del servicio. Dimensión primaria de agregación y de SLO.
- `env` — `prod` | `staging` | `dev`. Evita duplicar queries por entorno.
- `tier` — `gold` | `silver` | `bronze`. Driver de la retention policy y del routing a LTS.
- `region` — cuando el servicio corre multi-región. Driver de failover y cost allocation.

Prohibidos: `user_id`, `request_id`, `trace_id`, `email`, cualquier free-form derivado de input de usuario. Para debug fine-grained se usa exemplar + Tempo.

### Naming conventions

- Métricas: `<namespace>_<subsystem>_<name>_<unit>`, snake_case; counters `_total`; histograms `_seconds` o `_bytes`.
- Recording rules: `<level>:<metric>:<op>` (p. ej. `job:http_requests:rate5m`).
- Alertas: `CamelCase`, descriptivas: `CheckoutErrorBudgetBurningFast`.
- Dashboards: `[<team>] <service> — <signal>` (p. ej. `[payments] checkout — RED`).
- Folders Grafana: uno por team, subfolder por `env` cuando aplique.

### Tiers y retention policy

| Tier     | Prom local | LTS (Mimir) | Downsampling    | Casos de uso |
|----------|-----------|-------------|-----------------|--------------|
| `gold`   | 15 d      | 2 años      | 5m@90d, 1h@2y   | SLO ingredients, business KPIs |
| `silver` | 15 d      | 90 d        | 5m@90d          | RED por servicio |
| `bronze` | 15 d      | ninguna     | n/a             | debug internals, dev, histograms detallados |

Qué tier se usa lo decide el team; platform aprueba promociones a `gold`.

### Dashboards as code

- Tooling obligatorio: **grafonnet** (jsonnet). Alternativa aceptable: Terraform `grafana/grafana` cuando ya exista stack TF.
- Ubicación: repo monorepo `observability/dashboards/`.
- Template obligatorio `service.libsonnet` para RED; cualquier servicio tier gold/silver se genera desde ahí.
- CI (ver §Consequences): render + lint con `dashboard-linter` + preview en Grafana efímera + comentario en PR con URL.
- Prohibido editar dashboards productivos desde la UI (RBAC bloquea `Editor` en folder `main`; `grizzly` sincroniza desde `git`).

### Alerts as code

- `PrometheusRule` versionado en `observability/rules/<team>/<service>.yaml`.
- Toda alerta requiere `labels.severity` (`page` | `warning` | `info`), `labels.team`, y `annotations.runbook_url` con URL válida.
- CI corre `promtool check rules` + `promtool test rules`. Sin tests, el PR falla el gate `rules-covered`.
- Un cambio a `expr` requiere un test que lo cubra; CI mide coverage de tests por `rules/*.yaml`.

### SLO contract per service

- Obligatorio para tier `gold` y `silver`. Opcional para `bronze`.
- Formato: `observability/slos/<service>.yaml` con `sli`, `objective`, `window`, `runbook`.
- Las burn-rate alerts MWMBR se generan automáticamente desde `slo.yaml` vía `sloth`.

### Ownership y routing

- Alertmanager enruta por `labels.team` × `labels.severity`:
  - `severity=page` → PagerDuty del team.
  - `severity=warning` → Slack `#alerts-<team>`.
  - `severity=info` → sólo loggeado, no notificación.
- Un dashboard sin `labels.team` se bloquea en CI.
- On-call rotation vive en PagerDuty, gestionada por el team con approval de platform.

### Presupuesto

Mensual, por servicio, con tope *soft* (alerta) y *hard* (bloquea nuevos tiers upgrades):

| Tier   | Soft cap / servicio | Hard cap / servicio |
|--------|---------------------|---------------------|
| gold   | $150                | $300                |
| silver | $60                 | $120                |
| bronze | $15                 | $30                 |

Base cuantitativa: estimado en ~25 k series + 10 GB logs/día + sampling 10 % traces para gold típico; se recalibra trimestralmente contra la factura real. Meta-dashboard muestra el consumo diario por servicio contra el cap; se dispara alerta `warning` al 80 % soft y `page` al 100 % hard.

## Consequences

**Positivas**
- Dashboards y alertas revisables como código: PR + aprobación del team dueño + aprobación de platform para cambios al contrato.
- Routing automático: ninguna alerta llega al oncall incorrecto.
- Costo medible y presupuestado: termina la sorpresa a fin de mes.
- Onboarding de un servicio nuevo pasa de 3 días (manual) a 30 min (template).

**Negativas / costo**
- Overhead inicial para migrar los 180 dashboards actuales y los 400 rules existentes. Plan en §Migration (ver ADR-OBS-001-migration-plan).
- Teams con casos edge (p. ej. ML batch jobs) necesitan excepciones explícitas documentadas.
- Grafana de preview añade ~$50/mes de infra.

**Riesgos y mitigaciones**
- *Riesgo:* teams se saltan el template y recrean dashboards manuales. *Mitigación:* RBAC `Viewer` en folders productivos salvo el bot de `grizzly`.
- *Riesgo:* lint demasiado estricto frena PRs legítimos. *Mitigación:* lint arranca en modo `warning`, pasa a `error` después de 1 mes.
- *Riesgo:* presupuesto por servicio penaliza a teams que miden mucho porque les importa. *Mitigación:* el cap es revisable por PR al ADR; no es castigo, es visibilidad.

## Alternatives considered

- **Dashboards manuales en Grafana + wiki de buenas prácticas**. Rechazado: es el estado actual, no funcionó. Nada obliga a aplicar las convenciones.
- **Datadog SaaS end-to-end** (abandonar Prometheus/Grafana). Rechazado: costo proyectado 4-6× superior al Mimir self-hosted actual; vendor lock-in alto; portabilidad OTel limitada. Se reconsidera si el costo de plataforma sube > $25 k/mes.
- **Tratar sólo alertas as code, dejar dashboards manuales**. Rechazado: los dashboards son el 70 % del dolor operativo actual; sólo alertas no mueve la aguja.
- **Un Prometheus por team sin plataforma común**. Rechazado: multiplica costo de operación, pierde cross-team queries, imposibilita SLOs comparables.

## Review cadence

Trimestral. Owner: Platform team. Cambios al contrato son PRs al repo `observability/adr/` revisados por el *platform guild* (platform + 2 representantes rotativos de teams consumidores). Migration plan de cambios breaking requerido antes del merge.
