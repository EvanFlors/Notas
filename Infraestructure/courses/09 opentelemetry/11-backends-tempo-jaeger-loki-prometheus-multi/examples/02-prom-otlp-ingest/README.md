# Ejemplo 02 — Prometheus con OTLP ingest nativo

Demostración de **Prometheus ≥ 2.47** aceptando OTLP directamente sin `remote_write`. El Collector OTel exporta OTLP a Prometheus; Prometheus lo recibe en `/api/v1/otlp/v1/metrics` gracias a `--web.enable-otlp-receiver`.

## Qué muestra

- Prometheus arrancado con las flags `--web.enable-otlp-receiver` y `--enable-feature=otlp-write-receiver`.
- Collector con un pipeline `metrics`: `otlp receiver` → `batch` → `otlphttp exporter` apuntando a `http://prometheus:9090/api/v1/otlp`.
- Generador de métricas sintéticas (`telemetrygen metrics`) emitiendo contadores e histogramas al Collector.
- Consulta final: `up` + la métrica sintética en PromQL.

## Levantar

```bash
docker compose up -d
open http://localhost:9090      # Prometheus UI
```

En Prometheus → **Graph** → prueba:

```promql
gen
rate(gen[1m])
```

(`gen` es el nombre por defecto que usa `telemetrygen` para contadores.)

## Archivos

- `docker-compose.yaml` — Prometheus (con flags OTLP) + Collector + telemetrygen.
- `prometheus.yml` — mínimo; sin scrape jobs externos.
- `otel-collector-config.yaml` — pipeline `metrics` OTLP → Prometheus OTLP ingest.
- `check.sh` — smoke test.

## Smoke test

```bash
bash check.sh
```

Verifica que Prometheus responde `ready`, que el Collector no acumula `send_failed_metric_points`, y que una query PromQL contra la métrica inyectada devuelve resultado.

## SKIP gracefully

Si `docker` o `docker compose` no están disponibles, `check.sh` sale `0` con `SKIP`.

## Limpieza

```bash
docker compose down -v
```
