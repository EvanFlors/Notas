# Lección — Observabilidad como plataforma: dashboards y alertas como código, gobernanza y costos

## 1. Punto de partida: la observabilidad "artesanal" no escala

En los módulos anteriores aprendimos a instrumentar, consultar, graficar, alertar, escalar y definir SLOs. Cada pieza funciona. Pero cuando una organización pasa de 3 servicios a 300, la observabilidad se comporta como cualquier otro sistema distribuido sin gobierno: dashboards duplicados, alertas sin dueño, reglas que nadie entiende, costos que explotan sin motivo claro, y un equipo de plataforma al que todo el mundo culpa cuando algo no se ve.

Este módulo responde a la pregunta: **¿cómo convierto "mi stack Prometheus+Grafana funciona" en "mi organización tiene una plataforma de observabilidad gobernada"?**

La respuesta tiene tres patas:

1. **Todo como código** — dashboards, alertas, folders, data sources, SLOs, oncall routing.
2. **Un contrato explícito** — convenciones de naming, labels obligatorios, retention, ownership, publicado como ADR y revisable.
3. **Costo controlado** — una *bill* de observabilidad que se mide, se presupuesta y se revisa.

Las secciones siguientes recorren cada pata y terminan con el ADR y el proceso.

## 2. Dashboards as code: por qué sacar JSON de Grafana del "click-ops"

El patrón habitual en organizaciones jóvenes es: alguien construye un dashboard en Grafana, lo deja ahí, otro lo clona, modifica una query, lo renombra "v2", y a los seis meses hay 40 variantes del "mismo" dashboard. Nadie sabe cuál es el bueno. Si Grafana se corrompe, se pierde todo. Si se migra entre instancias, hay que exportar/importar a mano.

El antídoto es **tratar dashboards como código**: viven en el repo, se revisan en PR, se despliegan por CI/CD, se versionan con `git`. Hay tres caminos principales:

### 2.1 `grafonnet` (jsonnet)

Jsonnet es un lenguaje de templating funcional (superset de JSON) mantenido por Google. `grafonnet` es la **librería oficial de Grafana Labs** escrita en jsonnet que expone los paneles, dashboards, queries, variables, etc., como funciones. Permite componer dashboards de forma programática:

```jsonnet
local g = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local service = 'checkout';

g.dashboard.new('RED — ' + service)
+ g.dashboard.withPanels([
    g.panel.timeSeries.new('Rate (rps)')
    + g.panel.timeSeries.queryOptions.withTargets([
        g.query.prometheus.new('prom', 'sum by (route)(rate(http_requests_total{service="%s"}[5m]))' % service),
    ]),
    g.panel.timeSeries.new('Errors (ratio)')
    + g.panel.timeSeries.queryOptions.withTargets([
        g.query.prometheus.new('prom', 'sum(rate(http_requests_total{service="%s",status=~"5.."}[5m]))/sum(rate(http_requests_total{service="%s"}[5m]))' % [service, service]),
    ]),
    g.panel.timeSeries.new('Duration p95 (s)')
    + g.panel.timeSeries.queryOptions.withTargets([
        g.query.prometheus.new('prom', 'histogram_quantile(0.95, sum by (le)(rate(http_request_duration_seconds_bucket{service="%s"}[5m])))' % service),
    ]),
  ])
```

Un `jsonnet` compila a JSON que Grafana entiende directamente. Beneficio enorme: **reutilización**. Un `service.libsonnet` describe "qué es un dashboard RED para cualquier servicio" y 50 servicios lo instancian con 3 líneas cada uno.

Alternativas al pure jsonnet: **cue** (lenguaje de configuración tipado), **go-grafana-dashboard**, **python grafanalib** (más limitado), **Terraform `grafana/grafana`** (buen fit si ya hay Terraform para infra).

### 2.2 `grizzly`

`grizzly` es un CLI de Grafana Labs que trata recursos de Grafana (dashboards, folders, alertas, library panels, data sources) como *kubectl*-style objects:

```bash
grr apply dashboards/            # push al Grafana remoto
grr diff dashboards/             # muestra el drift
grr pull -t Dashboard -o out/    # pull para rescatar
```

Entiende tanto JSON como jsonnet. Es la pieza que convierte "tengo el jsonnet compilado" en "está publicado en Grafana" de forma idempotente.

### 2.3 JSON crudo + CI

Más humilde: exportar el JSON desde la UI, meterlo en el repo, y provisionarlo con el provisioning nativo de Grafana (ConfigMap con label `grafana_dashboard=1` en kube-prometheus-stack). Es el camino de entrada. Pero sin templates reaparece la duplicación.

### 2.4 Lint y validación

Grafana publica `dashboard-linter` que detecta smells: queries sin `rate()` sobre counters, paneles sin unit, paneles sin descripción, variables rotas. Integrarlo en CI corta errores en el PR.

## 3. CI de dashboards: preview en PR

Un dashboard es visual: revisar un diff de JSON no basta. El patrón maduro:

1. El PR modifica el `.libsonnet` o `.jsonnet`.
2. CI compila a JSON (`jsonnet -J vendor/ dashboards/service-red.jsonnet > out.json`).
3. CI lo publica a una **instancia Grafana de preview** (un folder "pr-123" via `grizzly apply --folder pr-123`).
4. Un bot comenta en el PR con la URL del preview.
5. Un reviewer humano abre la URL, compara con el actual, aprueba o pide cambios.
6. Al merge, el workflow despliega al Grafana productivo.

Beneficios: no se mergea JSON a ciegas. Costo: necesitas una Grafana adicional (puede ser efímera, se levanta por PR y se tira al cerrar). En Grafana Cloud existen *public dashboards* que simplifican el preview externo.

## 4. Templates y Golden Path: "cada servicio recibe su dashboard"

El salto cualitativo es dejar de **escribir** dashboards y pasar a **generarlos**. Un servicio declara qué es (en `service.yaml` o Backstage `catalog-info.yaml`), y la plataforma produce:

- Dashboard RED (rate, errors, duration) por `service`.
- Dashboard USE (utilization, saturation, errors) para los nodos/pods que lo corren.
- `PrometheusRule` con las alertas base (burn-rate SLO, pod crashloop, high-latency).
- Entrada en el folder de Grafana del team dueño, con permisos aplicados.
- Rotación on-call en PagerDuty/Opsgenie etiquetada con `team=X service=Y`.

Esto es un **Golden Path**: el camino recomendado y por default. Nada impide salirse (un servicio con métricas raras tendrá su dashboard custom), pero el 90 % recibe gratis lo correcto. Backstage con *software templates* es el frontal UI/CLI estándar.

El efecto es doble:
- **DX**: un dev nuevo no decide cómo nombrar su `_total`; sigue el template y listo.
- **Gobernanza**: todos los servicios tienen `team`, `service`, `env`, `tier` porque el template los pone.

## 5. Alerts as code: `PrometheusRule` versionado + `promtool test rules`

Las alertas Prometheus (`PrometheusRule` CRD en el Operator, o YAML plano en Prometheus-vanilla) **ya son texto** — así que `git` las trata bien. Lo que falla sin disciplina:

- No se testean, nadie sabe si disparan cuando deberían.
- Cambios silenciosos a `expr` o `for` que generan ruido semanas después.
- Reglas sin `labels: {severity, team, runbook}` o sin `annotations: {summary, description, runbook_url}` → la alerta llega al oncall sin contexto.

El estándar maduro:

```yaml
groups:
  - name: checkout-slo
    rules:
      - alert: CheckoutErrorBudgetBurningFast
        expr: |
          (
            job:slo_errors:ratio_rate_1h{service="checkout"} > (14.4 * 0.001)
            and
            job:slo_errors:ratio_rate_5m{service="checkout"} > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity: page
          team: payments
          service: checkout
          slo: availability
        annotations:
          summary: "Checkout está quemando error budget 14.4x más rápido de lo sostenible"
          description: "Burn rate 1h y 5m superan 14.4x el objetivo del 99.9%."
          runbook_url: "https://runbooks.example.com/checkout/slo-burn"
```

Y en CI:

```bash
promtool check rules rules/*.yaml
promtool test rules tests/*.yaml
```

Donde `tests/*.yaml` describe *input series* y *resultado esperado* (alerta activa o no en el minuto N). Es *unit test* real para alertas. Un cambio a `expr` que rompe un test falla el PR.

## 6. Gobernanza: naming, labels, retention, SLO, ownership

El **contrato de observabilidad** es un documento (ADR) que fija convenciones. Las piezas típicas:

### 6.1 Naming conventions

- Métricas: `<namespace>_<subsystem>_<name>_<unit>` (ya cubierto en `obs-03`). Namespace == dominio o equipo, no proyecto efímero.
- Recording rules: `<level>:<metric>:<operation>` (`job:http_requests:rate5m`).
- Alertas: `CamelCase` descriptivo, no `alert1`. Prefijo opcional `TeamServiceCondition`.
- Dashboards: `[Team] Service — Signal` (`[payments] checkout — RED`).
- Folders Grafana: uno por equipo (`payments`, `platform`, `search`), con subfolders por entorno si hace falta.

### 6.2 Labels obligatorios

Toda métrica *de aplicación* debe tener como mínimo:

| Label      | Valor                                   | Sentido |
|-----------|------------------------------------------|---------|
| `team`    | nombre del team dueño                    | ownership, routing |
| `service` | nombre del servicio                      | agregación, SLO |
| `env`     | `prod` \| `staging` \| `dev`            | separar entornos sin duplicar queries |
| `tier`    | `gold` \| `silver` \| `bronze`          | retención, severidad, costo |
| `region`  | si aplica                                | failover, cost allocation |

Se imponen por `external_labels` del Prometheus del cluster (gratis para todas las métricas de ese Prometheus), por relabel al scrape, y por convenciones del instrumentation library/middleware.

Lo que **no** debe aparecer: `user_id`, `request_id`, `trace_id`, `email`, `path` con parámetros, timestamps. Ya lo cubrimos en `obs-03` y `obs-10`; el contrato lo hace oficial.

### 6.3 Retention policy por tier

No todas las métricas valen lo mismo:

| Tier     | Retención Prom local | Retención LTS      | Downsampling | Ejemplos |
|----------|----------------------|--------------------|--------------|----------|
| `gold`   | 15 d                 | 2 años             | 5m@90d, 1h@2y | SLO ingredients, business KPIs |
| `silver` | 15 d                 | 90 d               | 5m@90d        | RED metrics por servicio |
| `bronze` | 15 d                 | ninguna            | n/a           | debug/internals, `_bucket` detallado |

El tier se expresa como label `tier=...` y el `remote_write` filtra qué envía al LTS. Esta política es **lo que gobierna la factura** (sección 8).

### 6.4 SLO contract per service

Cada servicio productivo *debe* tener un `slo.yaml`:

```yaml
service: checkout
owner: payments
tier: gold
slos:
  - name: availability
    sli: >
      sum(rate(http_requests_total{service="checkout",status!~"5.."}[5m]))
      / sum(rate(http_requests_total{service="checkout"}[5m]))
    objective: 0.999
    window: 30d
    runbook: https://runbooks.example.com/checkout/availability
  - name: latency
    sli: >
      histogram_quantile(0.99, sum by (le)(rate(http_request_duration_seconds_bucket{service="checkout"}[5m]))) < 0.3
    objective: 0.99
    window: 30d
```

De ahí se *generan* las burn-rate alerts (ver `obs-14` y tooling `sloth`/OpenSLO).

### 6.5 Ownership y runbooks

Cada alerta tiene `labels.team` (routing) y `annotations.runbook_url` (acción). Sin runbook, el PR no se mergea. Un runbook mínimo responde: qué significa, cómo verificar, cómo mitigar, cuándo escalar, qué dashboard mirar.

## 7. Grafana folders + permisos; routing a PagerDuty/Opsgenie

Grafana soporta folders con RBAC: cada team ve/edita su folder, lectura pública del resto. Combinado con el contrato de naming, cada dashboard aterriza en el folder correcto automáticamente (via `grizzly apply --folder payments`).

Alertmanager enruta por label `team`:

```yaml
route:
  group_by: ['alertname', 'team', 'service']
  receiver: default
  routes:
    - matchers: [team="payments", severity="page"]
      receiver: payments-pagerduty
    - matchers: [team="payments", severity="warning"]
      receiver: payments-slack
    - matchers: [team="platform", severity="page"]
      receiver: platform-opsgenie
```

Los receivers PagerDuty/Opsgenie reciben no sólo "alerta disparada" sino **el contexto**: `summary`, `description`, `runbook_url`, link al dashboard, link al silence. Mientras más self-service sea para el oncall, menos tickets de "¿qué hago con esto?".

Patrón de *enrichment*: a veces se mete un *webhook intermedio* (p. ej. karma, alerta-manager-webhook-logger) que añade links a Grafana Explore con la query, exemplar al trace, etc. Para equipos maduros vale la pena.

## 8. Costo de observabilidad: la "bill"

La trampa clásica: la observabilidad "sale gratis" porque *no se mide*. En la realidad tiene costo computable y a menudo mayor del esperado.

### 8.1 Qué forma la factura

**Métricas** (Prometheus / Mimir / VictoriaMetrics / Grafana Cloud):
- `active_series` × factor de retención. Regla de bolsillo con Prometheus single: ~3 KB/serie activa en RAM; en LTS (Mimir, VM) la unidad común es **$ por 1 000 series activas / mes**.
- Ingest rate (samples/s) para storage write path; ~1-2 B por sample comprimido.
- Query cost (CPU + egress).

**Logs** (Loki / Elastic / Datadog Logs / CloudWatch Logs):
- Volumen ingerido en GB/día — es la dimensión que domina. Loki ~\$0.5-2 /GB ingested; providers SaaS ~\$2-10 /GB.
- Retención (object storage barato, pero se suma).
- Query (scan) cost.

**Trazas** (Tempo / Jaeger / Honeycomb / Datadog APM):
- Spans/s × sampling rate × retención.
- Habitualmente se samplea 1-10 % en head sampling; tail sampling reduce menos pero conserva lo "raro".

**Egress** (muy olvidado):
- `remote_write` entre regiones o cuentas AWS: tráfico inter-AZ/región factura.
- Agentes que mandan logs/metrics a SaaS: tráfico de salida.

**Infra base** (nodos del propio stack): a menudo poco frente a lo anterior, salvo en LTS a gran escala.

### 8.2 Fórmula de bolsillo

Una aproximación mensual útil:

```
Bill ≈ Metrics_cost + Logs_cost + Traces_cost + Egress_cost + Infra_cost

Metrics_cost       = active_series_total / 1000 × price_per_1k_series_month
Logs_cost          = log_GB_per_day × 30 × price_per_GB_ingested
Traces_cost        = spans_per_sec × 86400 × 30 × sampling × price_per_1M_spans / 1e6
Egress_cost        = egress_GB_month × price_per_GB_egress
```

Donde `active_series_total = sum_over_services(series_per_service)` y `series_per_service ≈ product(cardinality_of_each_label)`. **Cada label nuevo en una métrica RED cuadriplica la cardinalidad típica** (status × method × route × tier). Ejemplo rápido: 50 servicios × 300 series/servicio = 15 000 series activas. A $0.80 / 1k series / mes → ~$12/mes. Fácil. Ahora, 1 servicio que mete `user_id` como label con 100 000 usuarios → 100 000 series extra → $80/mes solo por ese bug. Multiplicado por 10 servicios que cometen el mismo error → $800/mes de métrica inútil.

### 8.3 Meta-observabilidad

El propio stack **debe** tener dashboards y alertas:

- `prometheus_tsdb_head_series` por tenant/servicio y su derivada.
- Top-10 métricas por cardinalidad (`topk(10, count by (__name__)({__name__!=""}))`).
- GB/día ingested en Loki, por tenant/servicio.
- Costo diario estimado — un recording rule que multiplica `active_series / 1000 * $/1k/mes / 30`.
- Alerta: "cardinalidad de servicio X creció >50 % en 24 h".

Esto es *meta-observabilidad*: la plataforma se observa a sí misma. Sin ella el presupuesto se descubre a fin de mes.

### 8.4 Palancas de reducción

1. **Drop labels tóxicas** por `metric_relabel_configs` (último recurso) o arreglar la instrumentación.
2. **Downsample** (Thanos compactor, Mimir, VM) — reduce costo de queries largas.
3. **Tier** — mandar sólo `gold`/`silver` a LTS; `bronze` muere a los 15 días.
4. **Retention policy** honesta por tier.
5. **Scrape interval** — bajar de 15 s a 60 s para `bronze` reduce 4× el storage.
6. **Logs: parsing en el agente** (Alloy/Vector) para extraer campos y luego **descartar** logs ruidosos antes de ingestar.
7. **Native histograms** sustituyendo histograms clásicos con muchos buckets (ganancia 10-100× en series).

## 9. Integración con IDP / Backstage

El punto final de la gobernanza: no obligar a nadie a *recordar* el contrato — hacerlo el default.

Backstage (IDP open source más popular) ofrece *software templates*: scaffolds que al crear un servicio nuevo generan:

- Repo con esqueleto de código ya instrumentado (Counter, Histogram, middleware RED listo).
- `catalog-info.yaml` con `team`, `tier`, `slo`.
- PR al repo de observabilidad añadiendo `service.libsonnet` (dashboard RED) + `rules/<service>.yaml` (alertas base) + entrada en el `slo.yaml` global.
- Alertmanager route generada.
- Oncall rotation creada en PagerDuty via API con el team correcto.

Un dev crea su servicio y 10 min después tiene dashboard, alertas, SLO y oncall. Esa es la plataforma. Y como todo salió del template, cualquier cambio al template se puede propagar (vía PRs automáticos) a todos los servicios existentes.

Si no se puede llegar a Backstage, el mismo resultado se consigue con un `cookiecutter` + script o un GitHub Actions template repo + composite action.

## 10. Proceso: ADR del contrato y su evolución

La **gobernanza no es un YAML, es un acuerdo**. El vehículo recomendado es un **ADR** (Architecture Decision Record) corto, con esta estructura:

```markdown
# ADR-OBS-001 — Platform Observability Contract

## Status
Accepted — 2026-03-15

## Context
<por qué ahora, qué duele hoy, qué se intentó antes>

## Decision
1. Labels obligatorios: team, service, env, tier, (region).
2. Naming: snake_case, sufijo de unidad, _total para counters.
3. Tiers: gold/silver/bronze — ver tabla retención.
4. Toda alerta requiere labels.team, labels.severity, annotations.runbook_url.
5. Dashboards se generan vía grafonnet desde service.libsonnet.
6. SLO per service obligatorio para tier gold y silver.
7. Routing Alertmanager por labels.team y labels.severity.
8. Presupuesto mensual: $X / servicio (gold), $Y (silver), $Z (bronze).

## Consequences
- Positivas: ...
- Negativas / costo: ...
- Riesgos y mitigaciones: ...

## Alternatives considered
- "Dashboards manuales" — rechazado porque ...
- "Datadog SaaS end-to-end" — comparado en ADR-OBS-003.

## Review cadence
Trimestral; owner: Platform team.
```

Y un proceso simple: cambios al contrato son PRs al repo del ADR, revisados por representantes de los teams consumidores de la plataforma, con migration plan para los servicios existentes.

## 11. Checklist de madurez

Un ejercicio útil al terminar este módulo: puntuar la organización en cada ítem (0 no, 0.5 parcial, 1 sí).

- Dashboards viven en `git` y se despliegan por CI.
- Existe al menos un template de dashboard reutilizado por N servicios.
- CI corre `promtool test rules` sobre las alertas en cada PR.
- CI publica preview de dashboards en PR.
- Todas las métricas tienen labels `team`, `service`, `env`, `tier`.
- Existe `slo.yaml` por servicio tier gold/silver.
- Alertas sin `runbook_url` fallan el lint.
- Alertmanager enruta por `team`.
- Dashboards y alertas tienen folder/ownership por team.
- Existe meta-observabilidad: dashboards del propio stack con `active_series`, `log_gb_day`, estimación de costo.
- Existe presupuesto mensual por servicio o por tier.
- Existe ADR del contrato, revisado trimestralmente.
- Existe template IDP (Backstage u otro) que genera observabilidad para servicios nuevos.
- Reviews de dashboards/alertas requieren aprobación del team dueño y de platform.

Una org "madura" puntúa > 11/14. < 7/14 → urgente volver aquí.

## 12. Qué llevarse

- **Observabilidad es un producto de plataforma**, con usuarios internos, SLAs internos, costo medible y backlog propio.
- **El código es la unidad de verdad**: dashboards, alertas, SLOs, routing, retención, templates — todo en `git`, revisado, testeado.
- **El contrato gobierna la plataforma**: labels, naming, tiers, retention, ownership, routing, presupuesto. Un ADR corto es mejor que un wiki largo.
- **El costo se mide o se descontrola**: factura mensual = series × $/1k + GB logs × $/GB + egress. Meta-observabilidad obligatoria.
- **Templates convierten decisiones en defaults**: Backstage/IDP cierra el ciclo DX ↔ gobernanza.

En el siguiente paso, aplicarás este módulo a tu capstone: redacta un ADR, genera un dashboard con grafonnet, computa la factura mensual del stack, y defiende las tres decisiones ante tradeoffs de DX, costo y cobertura.
