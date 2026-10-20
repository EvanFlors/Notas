# Ejemplo 01 — Tempo con Collector OTel

Stack mínimo reproducible: **OTel Collector** → **Tempo** → **Grafana**, con un generador sintético de traces (`telemetrygen`).

## Qué muestra

- Collector OTel contrib recibe OTLP (gRPC `:4317`, HTTP `:4318`).
- Un pipeline `traces` con `batch` processor y `otlp` exporter hacia Tempo (`tempo:4317`).
- Tempo monolítico con `filesystem` storage (apto para lab).
- Grafana preprovisionado con Tempo como data source — permite TraceQL inmediato.
- Un contenedor `trace-gen` (basado en `otelcontribcol`'s `telemetrygen`) emite traces continuamente.

## Levantar

```bash
docker compose up -d
# espera ~15 s a que Tempo + Collector estén listos
open http://localhost:3000     # Grafana (anonymous admin)
```

En Grafana → **Explore** → Tempo → **Search** o TraceQL:

```traceql
{ resource.service.name = "trace-gen" }
{ duration > 10ms }
{ status = error }
```

## Archivos

- `docker-compose.yaml` — Collector, Tempo, Grafana, trace-gen.
- `otel-collector-config.yaml` — pipeline `traces` OTLP→Tempo.
- `tempo-config.yaml` — Tempo monolithic, filesystem storage.
- `grafana-datasources.yaml` — provisioning del data source Tempo.
- `check.sh` — smoke test con SKIP gracefully si docker no está.

## Smoke test

```bash
bash check.sh
```

Verifica que Collector y Tempo arrancan, que `telemetrygen` emite y que `/api/search` en Tempo devuelve al menos un trace.

## SKIP gracefully

Si `docker` o `docker compose` no están disponibles, `check.sh` sale `0` con mensaje `SKIP`.

## Limpieza

```bash
docker compose down -v
```
