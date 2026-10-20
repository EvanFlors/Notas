# Ejemplo 02 — Top ofensores de cardinalidad

## Concepto que demuestra

- Diagnosticar la TSDB de un Prometheus en vivo con el endpoint `/api/v1/status/tsdb`.
- Correr las queries estándar para encontrar métricas y labels con cardinalidad problemática.
- Interpretar la salida y decidir qué acción tomar.

## Prerrequisitos

- Un Prometheus corriendo accesible por HTTP (default `http://localhost:9090`).
- `curl` y `jq` (opcional pero recomendado).
- Si no hay Prometheus accesible, el script degrada con `SKIP`.

## Archivos

- `queries.md` — las queries diagnósticas comentadas.
- `inspect.sh` — script que llama al endpoint TSDB y lanza las queries vía API.

## Ejecución

```bash
cd examples/02-cardinality-top-offenders
chmod +x inspect.sh

# Default: http://localhost:9090
./inspect.sh

# O apuntando a otro endpoint:
PROM_URL=http://prometheus.monitoring.svc:9090 ./inspect.sh
```

Salida esperada (con Prometheus accesible):

```
== TSDB status (seriesCountByMetricName top 10) ==
  prometheus_tsdb_head_series: 123
  up: 45
  ...

== topk(5, count by (__name__)({__name__!=""})) ==
  http_request_duration_seconds_bucket: 870
  ...
```

Sin Prometheus accesible:

```
SKIP: Prometheus not reachable at http://localhost:9090
```

## Queries

### Q1 — top métricas por nº de series

```promql
topk(10, count by (__name__)({__name__!=""}))
```

Interpretación: lectura directa de las "métricas gordas". `*_bucket` suele dominar porque es N buckets × combinaciones de labels.

### Q2 — top valores de una label en una métrica sospechosa

```promql
# Si Q1 señaló "my_app_requests_total":
count by (user_id) (my_app_requests_total)
count by (path)    (my_app_requests_total)
```

Interpretación: la label que devuelva miles de valores es la ofensora.

### Q3 — crecimiento reciente de series

```promql
rate(prometheus_tsdb_head_series_created_total[5m])
```

Interpretación: si está muy por encima de `rate(prometheus_tsdb_head_series_removed_total[5m])`, estás acumulando series — algo nuevo está creando labels.

### Q4 — tiempo de evaluación de reglas (síntoma indirecto)

```promql
topk(5, prometheus_rule_evaluation_duration_seconds)
```

Interpretación: reglas lentas suelen apuntar a series con muchas combinaciones de labels, antesala del problema.

## Qué debes observar

- La métrica `prometheus_tsdb_head_series` es tu *watermark*: alerta sobre ella.
- El endpoint `/api/v1/status/tsdb` es la **primera parada** en un incidente — no necesitas PromQL, solo `curl`.
- Si una métrica aparece con 5+ dígitos de series y no estaba antes, mira `git log` del `prometheus.yml` y del código de la app: alguien añadió una label.

## Limpieza

Nada que limpiar — solo consultas de lectura.
