# Ejemplo 03 — Métricas del CI/CD: qué medir y cómo

> Lectura y análisis. Objetivo: dejar claro qué 4 métricas usa un dashboard de plataforma y cómo se consultan.

## 1. Las 4 métricas que no pueden faltar

| Métrica | Para quién | Cómo la obtienes | Umbral de alerta típico |
|---------|------------|------------------|-------------------------|
| **Pipeline duration (p50, p95)** | Developers, Platform | GraphQL API `pipeline(duration)` o Prometheus `ci_pipeline_duration_seconds` | p95 > 2× p95 histórico. |
| **Job success rate** | Platform, Owners de job | Suma `success / (success + failed)` sobre ventana 7d | <95% consistente ⇒ *flaky*. |
| **Queue time** (pending→running) | Platform | `ci_job_queued_duration_seconds` del runner exporter | p95 > 60 s en horario pico. |
| **Minutos consumidos** | FinOps, Platform | `ci_runner_job_duration_seconds_total` agregado por grupo | spike > 2× baseline semanal. |

Secundarias útiles cuando tengas las 4 primarias:

- **Cache hit ratio** por job: baja detecta claves mal diseñadas.
- **Artifact size** por job: artefactos pesados ralentizan downstream.
- **Retried jobs**: proxy adicional de flakiness.
- **Catalog adoption**: nº de proyectos que incluyen cada componente (grep nocturno).

## 2. Fuentes

### Prometheus exporter oficial

GitLab publica `/metrics` en:

- **Instance**: `gitlab-exporter` + varias métricas de app (`gitlab_sidekiq_*`, `gitlab_ci_*`).
- **Runner**: `gitlab-runner` expone `gitlab_runner_jobs`, `gitlab_runner_job_duration_seconds_bucket`, `gitlab_runner_concurrent`, etc.

Config mínima en el runner (`config.toml`):

```toml
listen_address = "0.0.0.0:9252"
```

Y Prometheus scrape:

```yaml
scrape_configs:
  - job_name: gitlab-runner
    static_configs:
      - targets: ["runner-1:9252", "runner-2:9252"]
```

### GraphQL API (históricos)

```graphql
query ProjectPipelines($fullPath: ID!) {
  project(fullPath: $fullPath) {
    pipelines(first: 50) {
      nodes {
        iid
        status
        duration
        queuedDuration
        createdAt
        ref
      }
    }
  }
}
```

Útil para rellenar dashboards con rangos de días/semanas que Prometheus no retiene por defecto.

### Audit events

Para "quién canceló/retried qué" y detectar patrones (p. ej. un job que un humano re-corre 5 veces a la semana).

## 3. PromQL de ejemplo

```promql
# p95 de duración de job por runner, últimos 15 min
histogram_quantile(0.95,
  sum(rate(gitlab_runner_job_duration_seconds_bucket[15m])) by (le, instance))

# success rate por proyecto (ventana 1h)
sum(rate(gitlab_runner_jobs{state="success"}[1h])) by (project)
  /
sum(rate(gitlab_runner_jobs[1h])) by (project)

# jobs en cola ahora mismo
sum(gitlab_runner_jobs{state="pending"}) by (instance)

# minutos consumidos por grupo (día)
sum(increase(gitlab_runner_job_duration_seconds_total[24h])) by (group) / 60
```

> Nota: nombres de métrica exactos pueden variar entre versiones del exporter. Verificar en Fase 4 contra el output real de `/metrics`.

## 4. Dashboard Grafana (layout mínimo)

```
┌────────────────────────┬────────────────────────┐
│ Pipeline duration p95   │ Job success rate (7d) │
│ (línea, por proyecto)   │ (tabla, top-10 peores) │
├────────────────────────┼────────────────────────┤
│ Queue time p95          │ Minutos consumidos    │
│ (línea, por runner)     │ (barra, por grupo, 7d)│
└────────────────────────┴────────────────────────┘
```

4 paneles, 1 pantalla, cubre el 80%.

## 5. Alertas (Alertmanager)

Reglas útiles:

- **Queue time alto**: `histogram_quantile(0.95, ...) > 60` durante 10 min ⇒ "falta capacidad de runner".
- **Success rate bajo por proyecto**: `rate_success < 0.9` durante 1h ⇒ "proyecto X *flaky*".
- **Pipeline runaway**: `pipeline_duration > 3h` ⇒ "pipeline fuera de control".
- **Catalog deprecated usage**: job diario con grep ⇒ "N proyectos aún usan componente deprecated".

## 6. Preguntas de autocomprobación

1. Si solo pudieras instrumentar **1 métrica**, ¿cuál y por qué?
2. Un dev dice "mi pipeline tarda el doble que la semana pasada". ¿Qué paneles miras y en qué orden?
3. ¿Por qué agregar por `project` y no por `job name` en Prometheus?
4. ¿Cómo distingues "falta capacidad de runner" de "jobs mal etiquetados"?
5. ¿Qué métrica te permite justificarle a Finance comprar más nodos para los runners propios?

Las respuestas se trabajan en la actividad `02-platform-adr-final`.
