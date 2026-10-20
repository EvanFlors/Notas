# Ejercicio operativo — Prometheus + Alertmanager + Grafana

Duración recomendada: **45–60 min** del total del examen.

## Objetivo

Dado el `starter/`, debes **corregir** la configuración y **entregar** una solución validable localmente con `promtool` y `amtool`. El dominio es un servicio HTTP (`checkout-api`) instrumentado con `prometheus_client` que ya reporta a `/metrics`.

## Prerrequisitos locales

- `promtool` ≥ 2.50 y `amtool` ≥ 0.27 en `$PATH`. Verifica:
  ```bash
  promtool --version
  amtool --version
  ```
- `jq` para inspeccionar el dashboard JSON (opcional).
- **No** se requiere acceso a Internet, ni cloud, ni cluster K8s.

> Si `promtool` o `amtool` **no** están instalados, `validate.sh` emite `SKIP: <tool> missing` y los criterios de "validación automática" de la rúbrica no otorgan puntaje máximo; la corrección se hace manualmente contra `VALIDATION.md`.

## Starter

```
starter/
  prometheus.yml          # dos jobs: static_configs con 1 target; k8s_sd mal filtrado
  metrics.txt             # /metrics sintético con 4 problemas plantados
  rules/
    rules.yml             # 1 alerta single-window ingenua + 0 recording rules
  alertmanager/
    alertmanager.yml      # route plano, sin inhibition, sin grouping fino
  README-STARTER.md       # pistas y pistas falsas plantadas
```

## Tareas

### OP-task-1 — PromQL + recording rules (10 pts)

En `solution/rules.yml`, define **al menos** las siguientes recording rules como *SLO ingredients* (nombradas con la convención `job:metric:op5m` / `op30d`):

- `job:http_requests:rate5m`
- `job:http_request_errors:ratio_rate5m`
- `job:http_request_errors:ratio_rate1h`
- `job:http_request_errors:ratio_rate6h`
- `job:http_request_duration_seconds:p99_rate5m` (usando `histogram_quantile` sobre `sum by (le, job) (rate(..._bucket[5m]))`)

Criterio: `promtool check rules solution/rules.yml` sale 0 y los nombres respetan la convención.

### OP-task-2 — relabel + cardinalidad (8 pts)

Corrige `solution/prometheus.yml`:

- añade `kubernetes_sd_configs` (job `kube-pods`) con `relabel_configs` que **mantengan sólo** pods con annotation `prometheus.io/scrape=true` y que respeten `prometheus.io/port` / `prometheus.io/path`.
- añade `metric_relabel_configs` para **dropear** la label `path` cuando `__name__=="http_request_duration_seconds_bucket"` y la ruta tiene formato de UUID (regex `^/items/[0-9a-f-]{36}$` → sustituye por `/items/:id`). Justifica en `notes.md` por qué eso **no** se hace en `relabel_configs`.
- documenta en `notes.md` los 4 problemas de `starter/metrics.txt` (`metrics-fix.md`), con el diff mínimo de nombre/tipo/labels por métrica.

### OP-task-3 — alertas MWMBR (12 pts)

En `solution/rules.yml`, añade un grupo `slo-checkout-availability` con un SLO **99.9% / 30d** sobre `job:http_request_errors:ratio_rate*`. Debe tener:

- `SLOBurnFast` con combinación `1h & 5m` burn rate ≥ `14.4 × (1 - SLO)`, `for: 2m`, `severity: page`.
- `SLOBurnSlow` con combinación `6h & 30m` burn rate ≥ `6 × (1 - SLO)`, `for: 15m`, `severity: ticket`.
- Cada alerta: `labels.service=checkout-api`, `annotations.summary`, `annotations.description`, `annotations.runbook_url` (puede ser URL ficticia pero coherente).

### OP-task-4 — tests de alertas (5 pts)

En `solution/rules_test.yml`, escribe casos para `promtool test rules`:

- `t1`: 15 min sin errores → **ninguna** alerta activa.
- `t2`: error ratio sostenido 1.5% durante 10 min → `SLOBurnFast` **ACTIVA** desde el minuto ~6.
- `t3`: pico de 30 s con error ratio 50% → **no** dispara `SLOBurnSlow` (demuestra que la ventana larga filtra).

Pasa con `promtool test rules solution/rules_test.yml`.

### OP-task-5 — Alertmanager routing + inhibition + dashboard (5 pts)

En `solution/alertmanager.yml`:

- `route` con child routes por `severity` (page → `receiver: pager`, ticket → `receiver: tickets`).
- `group_by: [alertname, service]`, `group_wait: 30s`, `group_interval: 5m`, `repeat_interval: 4h` (justifica en `notes.md`).
- Al menos una regla de `inhibit_rules`: `severity=page` del mismo `service` silencia `severity=ticket`.
- Receivers con webhooks placeholder (`url: http://localhost:9999/__REDACTED__`), **ningún secreto real**. Debe pasar `amtool check-config solution/alertmanager.yml`.

En `solution/dashboards/service-red.json`: dashboard Grafana (export válido) con 4 paneles (Rate, Error ratio, p95, p99) parametrizados por `$service`, usando las recording rules definidas en OP-task-1.

## Validación

```bash
bash operative/validate.sh
```

El script:

1. Verifica presencia de `promtool`/`amtool` (sale con `SKIP` si faltan).
2. Ejecuta `promtool check config solution/prometheus.yml`.
3. Ejecuta `promtool check rules solution/rules.yml`.
4. Ejecuta `promtool test rules solution/rules_test.yml`.
5. Ejecuta `amtool check-config solution/alertmanager.yml`.
6. Verifica que `solution/dashboards/service-red.json` sea JSON válido y use las recording rules esperadas (grep de `job:http_request_errors:ratio_rate5m`).
7. Busca red flags obvias: labels `user_id|request_id|email`, `cosign --insecure`, `summary(...)quantile=`, tokens no redactados.

Pega el log completo en `solution/notes.md`.
