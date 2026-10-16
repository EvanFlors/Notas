# obs-08 — Grafana en profundidad

## Identificación
- **ID:** `obs-08-grafana-deep`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:**
  - `obs-04-promql-fundamentals`
  - `obs-05-exporters-and-relabeling`

## Objetivo
Construir y **gobernar** dashboards eficaces en Grafana: elegir el panel correcto, parametrizar con variables, transformar datos del lado del cliente, provisionar todo desde YAML y versionar los dashboards *as code*.

## Temas y subtemas
1. **Data sources**: añadir Prometheus (y referencia a Loki, Tempo, Postgres); UID estable; defaults.
2. **Dashboards y paneles**: `time series`, `stat`, `gauge`, `bar chart`, `table`, `heatmap`, `state timeline`, `status history`; cuándo usar cada uno.
3. **Queries por panel**: múltiples queries, legend formatting (`{{job}} {{instance}}`), overrides por serie, unidades, min/max.
4. **Variables**: `query`, `custom`, `datasource`, `interval`, `__all` y *chained vars*; `$__rate_interval`, `$__range`, `$__interval`.
5. **Transformations**: `merge`, `join by field`, `reduce`, `filter by name/value`; cuándo transformar vs cuándo re-querear.
6. **Templating y repetición** de paneles/filas por variable.
7. **Alerting UI** de Grafana (motor unificado desde v8; coexistencia con Alertmanager).
8. **Provisioning**: data sources, dashboards, alerts y notificadores desde YAML (`/etc/grafana/provisioning/...`).
9. **Roles, permisos y folders**: Viewer/Editor/Admin, equipos, carpetas como unidad de permisos.
10. **Dashboards as code**: JSON exportado, `grizzly` (CLI estilo kubectl para Grafana) y `grafonnet` (DSL jsonnet).
11. **Buenas prácticas**: un dashboard = una pregunta; filas colapsables; evitar paneles "mapa de calor sin eje".
12. **Governance**: naming, ownership, retention de dashboards huérfanos.

## Conceptos internos (fundamentos)
- Grafana **no almacena métricas**. Cada panel es una query en tiempo real contra el data source.
- Las variables se resuelven en el **navegador** en cada carga; una variable mal filtrada puede disparar N queries pesadas.
- Un dashboard provisionado desde YAML es **inmutable** por UI (badge "Provisioned"): quien edita debe hacerlo en el repo.
- `grizzly` + `grafonnet` permiten tratar dashboards como código normal (PRs, review, lint, diff).

## Competencias
- **Conceptual:** justificar la elección de panel según la pregunta.
- **Operativa:** parametrizar dashboards con variables y transformations para servir a varios entornos/servicios.
- **Arquitectónica:** gobernar la plataforma con provisioning y dashboards *as code*.

## Ejemplos
- [`examples/01-dashboard-capstone-red/`](examples/01-dashboard-capstone-red/) — dashboard RED del capstone (FastAPI mock) provisionado.
- [`examples/02-variables-and-templating/`](examples/02-variables-and-templating/) — variables `query` encadenadas con `__all` y repetición de paneles.
- [`examples/03-provisioning-dashboards/`](examples/03-provisioning-dashboards/) — provisioning completo: data source + dashboards + folder + alert rule.

## Actividades
- [`activities/01-build-capstone-dashboard/`](activities/01-build-capstone-dashboard/) — **guided-lab**: construir el dashboard RED del capstone y provisionarlo.
- [`activities/02-dashboards-as-code/`](activities/02-dashboards-as-code/) — **independent**: convertir un dashboard JSON a `grafonnet` (jsonnet) y renderizarlo.

## Entregables
- Dashboards del capstone exportados a JSON y provisionados desde YAML.
- Un dashboard escrito como código `jsonnet` (grafonnet) con su `rendered.json` generado por CI local.

## Criterios de evaluación
- **Conceptual:** rediseñar un dashboard "mapa de calor sin eje" en uno útil.
- **Operativa:** provisionar un dashboard sin tocar la UI y demostrarlo con el badge *Provisioned*.
- **Arquitectónica:** justificar `grafonnet` vs JSON exportado para una plataforma con 50+ servicios.

## Recursos
- [`theory/lesson.md`](theory/lesson.md)
- [`resources/links.md`](resources/links.md)
