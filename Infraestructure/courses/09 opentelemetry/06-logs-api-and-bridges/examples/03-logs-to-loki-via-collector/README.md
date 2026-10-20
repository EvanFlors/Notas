# Ejemplo 03 — Logs OTel → Collector → Loki (en Grafana)

Stack `docker compose` con tres servicios:

- **loki** — backend de logs.
- **grafana** — UI pre-configurada con datasource de Loki.
- **otel-collector** — recibe OTLP (gRPC `:4317`) y exporta a Loki (`loki` exporter de contrib).

Y una app Python local que **no corre en Docker** sino en tu host; emite logs OTLP al Collector mapeado a `localhost:4317`.

## Prerrequisitos

- `docker` + `docker compose`.
- `python3` 3.10+.
- Puertos libres: `3000` (Grafana), `3100` (Loki), `4317`/`4318` (Collector).

Si no tienes Docker, salta este ejemplo. El wiring de la app es idéntico al ejemplo 02; cambia solo el exporter (OTLP en lugar de Console).

## Correr

```bash
cd examples/03-logs-to-loki-via-collector

# 1. Levantar stack
docker compose up -d
docker compose ps      # loki, grafana, otel-collector corriendo

# 2. App Python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py         # genera N spans + N logs
```

## Qué esperar

- En Grafana (`http://localhost:3000`, user `admin` / pass `admin`), ve a **Explore → Loki**.
- Query: `{service_name="example-03"}`.
- Verás los logs con `trace_id` como attribute. En versiones recientes del `loki` exporter, el `trace_id` se promueve automáticamente para que `TraceToLogs` pueda saltar entre ambos datasources.

## Limpieza

```bash
docker compose down -v
deactivate 2>/dev/null || true
rm -rf .venv
```
