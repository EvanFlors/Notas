# Ejemplo 02 — Definición de SLOs de la propia plataforma

> Lectura y análisis. Sin ejecución. Objetivo: ver **cuatro SLOs concretos** para la plataforma, con SLI, objetivo, error budget y burn-rate alerts, listos para calcar.

## 1. Por qué la plataforma necesita sus propios SLOs

Repasado en `theory/lesson.md` §4. En una línea:

> Sin SLO de la plataforma, los equipos de producto **no pueden razonar** sobre su propio riesgo, el platform team **no tiene presupuesto de error**, y el liderazgo **no sabe decir** si estamos mejorando.

Lo que sigue son **cuatro SLOs mínimos** redactados en formato operable, no en formato aspiracional.

## 2. SLO #1 — Backstage uptime

### SLI

Fracción de requests HTTP que terminan en 2xx o 3xx respecto al total, excluyendo 4xx que no sean 429, medido en la puerta del ingress.

```
SLI = (count(2xx) + count(3xx)) / (count(2xx) + count(3xx) + count(5xx) + count(429))
```

### SLO

**99.5 %** sobre ventana de **30 días** rodantes.

### Error budget

`1 − 0.995 = 0.005` → **3 h 36 min** de downtime permitido al mes.

### Burn-rate alerts (patrón SRE Workbook)

```yaml
# Fast burn: consumiría el budget mensual en ~2h si continúa
- alert: BackstageSLOFastBurn
  expr: |
    (1 - (sum(rate(http_requests_total{job="backstage",status=~"2..|3.."}[1h]))
          / sum(rate(http_requests_total{job="backstage",status!~"4[0-9][0-9]"}[1h])))) > (14.4 * 0.005)
    and
    (1 - (sum(rate(http_requests_total{job="backstage",status=~"2..|3.."}[5m]))
          / sum(rate(http_requests_total{job="backstage",status!~"4[0-9][0-9]"}[5m])))) > (14.4 * 0.005)
  for: 2m
  labels:
    severity: page
  annotations:
    summary: "Backstage burn rate 14.4x (fast)"

# Slow burn: consumiría el budget mensual en ~24h si continúa
- alert: BackstageSLOSlowBurn
  expr: |
    (1 - (sum(rate(http_requests_total{job="backstage",status=~"2..|3.."}[6h]))
          / sum(rate(http_requests_total{job="backstage",status!~"4[0-9][0-9]"}[6h])))) > (6 * 0.005)
    and
    (1 - (sum(rate(http_requests_total{job="backstage",status=~"2..|3.."}[30m]))
          / sum(rate(http_requests_total{job="backstage",status!~"4[0-9][0-9]"}[30m])))) > (6 * 0.005)
  for: 15m
  labels:
    severity: ticket
```

### Decisiones derivadas

- Si `error_budget_remaining < 25 %` al día 20 del mes: **feature freeze** del platform team hasta recuperar budget.
- Si cae > 2 meses seguidos: **re-evaluar objetivo** (quizá 99.5 es demasiado ambicioso para el tamaño actual del equipo).

## 3. SLO #2 — Latencia del scaffolder (p95)

### SLI

Latencia end-to-end entre `scaffolder_task_started` y `scaffolder_task_finished`, medida en el backend del scaffolder.

### SLO

**p95 < 60 s** sobre ventana de **7 días**, medido como fracción de ejecuciones por debajo del umbral.

```
SLI = count(latencia < 60s) / count(total ejecuciones)
SLO: SLI >= 0.95
```

### Error budget

`1 − 0.95 = 0.05` → **5 %** de ejecuciones pueden exceder 60 s en los últimos 7 días.

### Burn-rate alerts

```yaml
- alert: ScaffolderLatencyBurn
  expr: |
    histogram_quantile(0.95,
      sum(rate(scaffolder_task_duration_seconds_bucket[1h])) by (le)
    ) > 60
  for: 15m
  labels:
    severity: ticket
  annotations:
    summary: "Scaffolder p95 > 60s (last hour)"
```

### Decisiones derivadas

- Si el p95 pasa de 60s de forma sostenida, el **template** se investiga primero (puede ser un step nuevo que mete overhead). Si no es un template concreto, se investiga el backend.
- Latencia > 2 min → el template deja de ser usable (los usuarios piensan que está roto y reintentan, agravando la cola).

## 4. SLO #3 — Catalog freshness

### SLI

Diferencia de tiempo (lag) entre `commit_push_timestamp` del repo donde vive `catalog-info.yaml` y `catalog_entity_updated_timestamp` en Backstage.

```
lag = max(catalog_entity_updated_timestamp - commit_push_timestamp)
      para todas las entidades actualizadas en la ventana
```

### SLO

**p99 lag < 5 min** sobre ventana de **7 días**.

### Error budget

`1 %` de updates pueden tardar más de 5 min — típicamente los que coinciden con un reload masivo o un rate limit del provider del catálogo.

### Burn-rate alerts

```yaml
- alert: CatalogFreshnessBurn
  expr: |
    histogram_quantile(0.99,
      sum(rate(catalog_sync_lag_seconds_bucket[30m])) by (le)
    ) > 300
  for: 10m
  labels:
    severity: ticket
  annotations:
    summary: "Catalog freshness p99 > 5min"
    runbook: "https://backstage.internal/runbooks/catalog-freshness"
```

### Decisiones derivadas

- Lag sostenido alto → verificar quota de API de GitHub / GitLab (es la causa más frecuente).
- Si el lag entre `commit → entity updated` es > 1 h, los dashboards de scorecards, los dueños y los filtros por tag **mienten**. Perdemos la confianza del catalog.

## 5. SLO #4 — MTTR en incidentes de plataforma

### SLI

Tiempo entre `incident_declared` (en PagerDuty / Opsgenie) e `incident_resolved` para incidentes **P1** y **P2** cuyo *affected service* es un componente de la plataforma (Backstage, scaffolder, catalog, plugins propios, Crossplane control plane).

### SLO

**p90 MTTR < 2 h** medido **trimestralmente**.

### Cálculo del budget

Ventana trimestral → ~90 d → typical P1/P2 count en una plataforma de tamaño medio: 5–15 por trimestre.
Budget: 10 % de incidentes pueden exceder 2 h (típicamente los que requieren intervención de vendor externo o rollback complejo).

### Alertas

Esto **no** es una métrica de burn-rate clásica (no es un ratio continuo). Es un KPI operacional:

- **Al cierre de cada incidente**: si el MTTR excedió 2 h, se añade a la lista de incidentes "sobre budget".
- **Semanal**: dashboard de "incidentes del trimestre + MTTR acumulado".
- **Fin de trimestre**: si el budget se agotó, el platform team **invierte en reliability** el siguiente trimestre:
  - Mejor runbooks.
  - Automatización de rollbacks.
  - Mejor on-call rotation.
  - Postmortems más estrictos.

## 6. Dashboard "Platform Status" (recomendado)

Panel único en Grafana/Backstage con:

```
┌─────────────────────────────────────────────────────────────┐
│  PLATFORM STATUS (last 30d)                                 │
├─────────────────────────────────────────────────────────────┤
│  Backstage uptime        99.63%  [SLO 99.5%]  budget 73%    │
│  Scaffolder p95           42s    [SLO <60s]   budget 61%    │
│  Catalog freshness p99   3m 15s  [SLO <5min]  budget 88%    │
│  MTTR P1/P2 p90          1h 24m  [SLO <2h]    budget 55%    │
├─────────────────────────────────────────────────────────────┤
│  Current state: HEALTHY (all SLOs within objective)         │
│  Release freeze: NO                                         │
│  Next review: 2026-11-01 (platform ops meeting)             │
└─────────────────────────────────────────────────────────────┘
```

El dashboard es **público interno** (todos los equipos pueden verlo), enlazado desde el README del catalog de Backstage y mencionado en el canal `#platform-announcements` cada lunes.

## 7. Qué NO poner como SLO

Tentaciones comunes a resistir:

- **"Número de servicios adoptados"** — es un **KPI** de producto, no un SLO. SLOs miden **fiabilidad**, no adopción.
- **"Satisfacción (CSAT)"** — igual, es KPI de producto. Útil, pero no un contrato de fiabilidad.
- **"Cobertura de tests"** — métrica interna de calidad; no un contrato con el consumidor.
- **100 % uptime** — mentira. Nadie opera a 100 %; prometer 100 % destruye credibilidad.
- **"P99 latencia < 10 ms"** sin volumen real — métricas sin tráfico son ruido estadístico.

El SLO debe ser:

- **Medible** con lo que ya instrumentas.
- **Significativo** para el consumidor (no "métrica interna").
- **Alcanzable** con el equipo y tiempo actual.
- **Defendible** cuando se incumple (hay runbook, hay postmortem, hay aprendizaje).

## 8. Qué llevarse

- Los **4 SLOs mínimos** son uptime, latencia del scaffolder, freshness del catalog y MTTR.
- Cada SLO tiene **SLI, objetivo, error budget y burn-rate alerts**.
- El **error budget** no es métrica contable: dispara **decisiones operativas** (freeze, inversión en reliability).
- Un **dashboard público interno** convierte los SLOs en contrato real con los consumidores.
- Lo que **no** es SLO: adopción, CSAT, cobertura. Son KPI, no contrato de fiabilidad.
