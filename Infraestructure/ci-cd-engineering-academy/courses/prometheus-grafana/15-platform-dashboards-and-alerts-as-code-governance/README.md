# obs-15 — Platform: dashboards & alerts as code, gobernanza y costos

## Identificación
- **ID:** `obs-15-platform-dashboards-and-alerts-as-code-governance`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `obs-08-grafana-deep`, `obs-11-scale-and-long-term-storage`, `obs-12-prometheus-operator-and-kube-prometheus-stack`, `obs-14-slo-and-burn-rate-alerts`

## Objetivo
Gobernar observabilidad como **plataforma interna**: dashboards y alertas versionados como código, generados por *templates*, revisados en PR, con convenciones, ownership, políticas de retención y un **presupuesto de costo** explícito. Al terminar deberías poder redactar y defender el "contrato de observabilidad" de tu organización.

## Temas y subtemas
1. **Dashboards as code**: por qué sacar el JSON de Grafana del "click-ops".
   - `grafonnet` (jsonnet library oficial de Grafana Labs).
   - `grizzly` (CLI que empuja/pulla dashboards, folders, alertas, library panels).
   - Alternativas: JSON exportado + `jsonnet`/Go templating; Terraform provider `grafana/grafana`.
2. **CI de dashboards**: lint (`grafana/dashboard-linter`), diff visual en PR (preview environment), schema validation.
3. **Templates / Golden Path**: "cada servicio nuevo recibe su dashboard RED + USE auto-generado desde un `service.yaml`".
4. **Alerts as code**: `PrometheusRule` versionado, revisado en PR, con tests `promtool test rules` corriendo en CI.
5. **Gobernanza**:
   - Naming conventions (`team_service_signal`).
   - Labels obligatorios (`team`, `service`, `env`, `tier`).
   - Retention policy por *tier* (gold/silver/bronze).
   - SLO contract por servicio (una fila por servicio con SLO, owner, runbook).
6. **Costo de observabilidad** ("observability bill"):
   - Active series (métricas) → RAM, storage, cardinalidad.
   - Logs ingested (GB/día) → ingest + storage + egress.
   - Trazas sampleadas, egress inter-AZ, long-term storage.
   - Meta-observabilidad: alertar cuando el costo de observar crece más que el servicio observado.
7. **Grafana folders y permisos** por equipo (RBAC).
8. **Integración con on-call**: PagerDuty, Opsgenie — routing + enrichment desde Alertmanager.
9. **IDP / Backstage**: plantilla `software template` que al crear un servicio genera dashboard + alerts + SLO + oncall rotation.
10. **ADR y proceso**: cómo documentar las decisiones ("el contrato") y evolucionarlas.

## Conceptos internos (fundamentos)
- **Sin código y sin revisión, los dashboards se multiplican y envejecen**. Observabilidad se degrada hasta volverse ruido; nadie sabe cuál es "el bueno".
- **Toda alerta sin ownership degenera en ruido**. El ownership (equipo, runbook) es un campo requerido, no decorativo.
- **El costo de observabilidad crece súper-linealmente con la cardinalidad** y con el número de servicios. Si no se mide, se descontrola — por eso hace falta *meta-observabilidad* (dashboards del propio stack).
- Un **template** convierte una decisión bien pensada *una vez* en el default para todos los servicios: ahorra discusión y hace la plataforma predecible.
- El **ADR del contrato** es el artefacto que hace que la gobernanza sea revisable y evolucionable; sin él, es folclore oral.

## Competencias
- **Conceptual:** explicar por qué dashboards y alertas deben vivir como código con los mismos controles que la app.
- **Operativa:** generar un dashboard desde `grafonnet`, enrutarlo por `grizzly`, correr `promtool test rules` en CI, publicar previews en PR.
- **Arquitectónica:** diseñar el "contrato de observabilidad" (labels obligatorios, tiers, retention, SLO, owner, routing) y presupuestar su costo mensual.

## Ejemplos
- `examples/01-grafonnet-baseline/` — `grafonnet` genera dashboard RED a partir de un `service.libsonnet`.
- `examples/02-pr-preview-dashboards/` — workflow GitHub Actions que lintea dashboards, publica preview y comenta en el PR.
- `examples/03-observability-bill-analysis/` — script que calcula la factura mensual a partir de un perfil (servicios, series por servicio, logs/día, retención).

## Actividades
- `activities/01-platform-contract-adr/` — redactar y defender un ADR del *platform observability contract*.
- `activities/02-cost-of-observability-exercise/` — computar la factura mensual de observabilidad para un perfil dado y proponer dos optimizaciones.

## Entregables
- ADR del contrato de observabilidad de la plataforma.
- Dashboard RED generado desde `grafonnet` para un servicio real del capstone.
- Workflow CI con lint + preview + `promtool test rules`.
- Hoja de cálculo (o script) con la factura mensual de observabilidad del capstone.

## Criterios de evaluación
- **Conceptual:** justifica por qué dashboards/alertas deben seguir el ciclo PR/review/tests.
- **Operativa:** su `grafonnet` genera un JSON válido; su CI linta y testea; preview en PR funciona.
- **Arquitectónica:** su contrato cubre naming, labels, retention, SLO, ownership, routing y presupuesto; defiende cada decisión frente a tradeoffs de DX, costo y cobertura.

## Recursos
Ver `resources/links.md` y `theory/lesson.md`. Lecturas clave: Grafana Labs "dashboards as code", `kubernetes-mixin`, Google SRE Workbook (cap. "Alerting on SLOs"), Backstage *software templates*, "Observability economics" (Charity Majors, Liz Fong-Jones).
