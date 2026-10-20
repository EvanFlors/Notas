# Ejemplo 03 — Classic histogram vs native histogram

## Concepto que demuestra

- Diferencia en **nº de series** entre un histogram clásico (con buckets) y un native histogram (una sola serie sparse).
- Cómo la **misma firma** `histogram_quantile()` funciona sobre ambos.
- Trade-offs de habilitación y migración.

## Prerrequisitos

- Conceptual — no requiere ejecución obligatoria. Opcionalmente:
  - Prometheus ≥ 2.40 con `--enable-feature=native-histograms`.
  - `prometheus_client` ≥ 0.19 para el productor (si quieres emitir native desde Python).
- Si no hay Prometheus con la feature activa, el ejemplo es **lectura**.

## Archivos

- `compare.md` — tabla comparativa y queries de verificación.
- `demo.sh` — opcional: lista cuántas series tienen las métricas `*_bucket` en tu Prometheus (indicativo de peso de classic histograms).

## Ejecución

```bash
cd examples/03-native-histogram-compare
chmod +x demo.sh
./demo.sh                      # usa PROM_URL=http://localhost:9090 por default
```

Salida esperada (con Prometheus accesible):

```
== Classic histogram series count (metrics ending in _bucket) ==
  http_request_duration_seconds_bucket: 870
  prometheus_http_request_duration_seconds_bucket: 160
  ...
  TOTAL classic bucket series: 1234
```

Sin Prometheus accesible:

```
SKIP: Prometheus not reachable at http://localhost:9090
```

## Comparativa

| Dimensión | Classic histogram | Native histogram |
|-----------|-------------------|------------------|
| Series por histogram | N (uno por bucket `le`) + `_count` + `_sum` | **1** sparse |
| Buckets | fijos al definir la métrica | exponenciales, `schema` configurable |
| Resolución | limitada por los buckets elegidos | mucho más fina (y adaptable) |
| Agregación cross-serie | correcta en histograms, errónea en summaries | correcta, nativa |
| Soporte cliente | universal | `prometheus_client` reciente, OTel, Go client |
| Soporte server | universal | ≥ 2.40 con `--enable-feature=native-histograms` |
| `histogram_quantile()` | sí | sí (misma firma) |

## Queries de comparación

```promql
# Cuántas series pesa un histogram clásico de latencia:
count({__name__="http_request_duration_seconds_bucket"})

# Lo equivalente en native sería 1 serie:
# http_request_duration_seconds (sin sufijo _bucket)
```

## Trade-offs al migrar

- **No es un drop-in**: el nombre de la métrica cambia (sin sufijo `_bucket`); dashboards antiguos pueden romperse.
- Puedes **convivir**: emitir ambas durante una ventana de migración.
- Reglas de alerta sobre `_bucket` dejan de aplicar — hay que reescribir las alertas o mantener dual-emit.
- Grafana ≥ 10/11 maneja native histograms sin fricciones; verificar en la versión del stack.

## Patrón de migración recomendado

1. Habilitar la feature en Prometheus (`--enable-feature=native-histograms`).
2. Instrumentar **nuevas** métricas directamente como native.
3. Para métricas existentes de alto volumen, convivir con dual-emit por 1 release.
4. Migrar dashboards y alertas al nombre sin `_bucket`.
5. Dejar de emitir el classic.

## Limpieza

Nada que limpiar — solo lectura.
