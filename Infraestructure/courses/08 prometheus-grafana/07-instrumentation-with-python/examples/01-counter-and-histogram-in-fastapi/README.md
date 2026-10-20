# Ejemplo 01 — Counter y Histogram en FastAPI

Mínimo viable: una app FastAPI con un `Counter` y un `Histogram` expuestos en `/metrics`.

## Requisitos

- Python 3.10+
- `pip install fastapi uvicorn prometheus_client`

## Correr

```bash
cd $(dirname "$0")
uvicorn app:app --port 8000 &
sleep 1
curl -s http://localhost:8000/health > /dev/null
curl -s http://localhost:8000/work > /dev/null
curl -s http://localhost:8000/metrics | grep -E '^(demo_requests_total|demo_request_duration_seconds)' | head -20
kill %1
```

## Qué observar

- `demo_requests_total{endpoint="/health"} 1` crece con cada petición.
- `demo_request_duration_seconds_bucket{endpoint="/work",le="0.25"} ...` acumula por bucket.
- `demo_request_duration_seconds_sum`, `_count` para calcular latencia media.

## Decisiones de diseño

- `endpoint` como único label para mantener cardinalidad baja (2 valores).
- Sufijo `_total` en Counter (requisito del convenio).
- Sufijo `_seconds` en Histogram y buckets elegidos para rango 5 ms – 1 s.
