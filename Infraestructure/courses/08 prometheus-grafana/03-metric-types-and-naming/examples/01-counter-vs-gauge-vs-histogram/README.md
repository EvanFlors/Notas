# Ejemplo 01 — counter vs gauge vs histogram (mock `/metrics`)

Levanta un mock `/metrics` con `python3 -m http.server` sirviendo un fichero estático con las tres formas canónicas. Útil para "ver con los ojos" el formato Prometheus text sin instrumentar nada.

## Prerrequisitos

- Python 3.8+ (sólo stdlib, nada que instalar).
- Puerto 8080 libre. Si no lo tienes, cambia `PORT` abajo.

Si no hay `python3`, el ejemplo **SKIP gracefully** con un mensaje.

## Contenido

- `metrics.txt` — fichero servido tal cual en `/metrics.txt` (lo renombraremos a `/metrics` conceptualmente).
- `run.sh` — levanta el server, hace `curl` y para el server.

## Ejecutar

```bash
cd examples/01-counter-vs-gauge-vs-histogram
./run.sh
```

Deberías ver las tres formas: un counter (`http_requests_total`), un gauge (`queue_depth`), y un histogram (`http_request_duration_seconds_bucket` + `_count` + `_sum`).

## Qué observar

1. El counter tiene `# TYPE ... counter` y acaba en `_total`.
2. El gauge **no** tiene sufijo `_total` y su `# TYPE` es `gauge`.
3. El histogram expone 3 artefactos: `_bucket{le="..."}`, `_count`, `_sum`. Los buckets son **acumulativos** (cada `le` incluye todo lo anterior).

## Limpieza

El propio `run.sh` mata el servidor al final. Si quedó colgado:

```bash
pkill -f "http.server 8080" || true
```
