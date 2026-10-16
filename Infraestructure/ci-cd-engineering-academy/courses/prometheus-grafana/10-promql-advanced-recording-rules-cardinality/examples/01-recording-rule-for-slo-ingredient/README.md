# Ejemplo 01 — Recording rule como "ingrediente SLO"

## Concepto que demuestra

- Cómo convertir una expresión costosa (ratio de errores HTTP) en una **recording rule** reutilizable.
- Convención de naming `level:metric:operations` (`job:http_errors:ratio5m`).
- Validación con `promtool check rules` sin necesidad de levantar Prometheus.

## Prerrequisitos

- `promtool` (viene con la distribución Prometheus). Si no está instalado, el ejemplo degrada con `SKIP`.
- Opcional: Prometheus corriendo localmente para ver las series materializadas.

## Archivos

- `rules.yml` — grupo de reglas con 3 ingredientes (rate, errors, ratio).
- `rule_test.yml` — test unitario para `promtool test rules` con series sintéticas.
- `run.sh` — script que corre `check rules` y `test rules`, con `SKIP` si falta `promtool`.

## Ejecución

```bash
cd examples/01-recording-rule-for-slo-ingredient
chmod +x run.sh
./run.sh
```

Salida esperada (con `promtool` instalado):

```
== promtool check rules ==
  SUCCESS: 3 rules found
== promtool test rules ==
  SUCCESS

OK: recording rules valid.
```

Sin `promtool`:

```
SKIP: promtool not installed. Install Prometheus to run checks.
```

## Qué debes observar

- Las 3 reglas se evalúan en el mismo grupo para que compartan el mismo instante y la última pueda referenciar las anteriores si quisiéramos encadenar.
- El `interval: 30s` del grupo controla con qué frecuencia Prometheus las corre, independiente del `scrape_interval` global.
- El nombre `job:http_errors:ratio5m` deja claro que es a nivel `job`, mide `http_errors`, y usa ventana 5 min. Un dashboard o alerta que consuma esto no necesita saber la expresión por detrás.

## Qué pasa si cambio el `by (job)` por `by (job, path)`

- Se multiplica la cardinalidad del resultado por el nº de paths.
- Un dashboard que agrupe por `job` tendrá que hacer `sum by (job)` encima — recuperando parte del coste que querías evitar.
- Si el objetivo es ver errores por path, considera **otra** recording rule separada (`job:http_errors:ratio5m_by_path`) para no mezclar propósitos.

## Patrón de uso aguas abajo

En un dashboard, el panel pasa de:

```promql
sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
  /
sum by (job) (rate(http_requests_total[5m]))
```

a:

```promql
job:http_errors:ratio5m
```

En una alerta (próximo módulo `obs-14`):

```yaml
- alert: HighErrorRate
  expr: job:http_errors:ratio5m > 0.05
  for: 5m
```

## Limpieza

Nada que limpiar — ningún estado persistente.
