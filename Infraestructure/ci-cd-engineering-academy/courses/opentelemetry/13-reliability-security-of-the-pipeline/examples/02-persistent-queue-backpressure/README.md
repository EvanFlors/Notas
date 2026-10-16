# Ejemplo 02 — Persistent queue y backpressure

## Concepto que demuestra

El `sending_queue` persistente en disco (`file_storage` extension) permite que el Collector sobreviva reinicios y caídas del backend sin perder datos. Verás:

1. Backend caído → la cola en disco crece.
2. Collector reiniciado mientras backend sigue caído → al volver, la cola está intacta.
3. Backend recuperado → los datos acumulados se entregan.

También verás `memory_limiter` activando bajo spike y rechazando ingestión con backpressure al cliente.

## Contexto

Materializa §5 y §6 de la lección. Requiere solo `docker compose`.

## Prerrequisitos

- `docker` + `docker compose`.
- Imagen `otel/opentelemetry-collector-contrib:0.110.0`.

## Archivos

- `files/docker-compose.yaml` — levanta Collector + "backend" (otro Collector en modo debug como stand-in).
- `files/collector.yaml` — Collector con `file_storage` + `sending_queue` + `memory_limiter`.
- `files/backend.yaml` — "backend" OTLP receiver con exporter debug.
- `files/generate-load.sh` — usa `telemetrygen` (contenedor) para empujar spans.
- `files/verify.sh` — ejecuta el ciclo caída→restart→recuperación.
- `files/clean.sh` — limpieza.

## Flujo

```bash
cd files
docker compose up -d
sleep 5

# Carga baseline (unos segundos)
bash generate-load.sh 5

# Mata el backend
docker compose stop backend

# Sigue generando carga — se irá a la cola persistente
bash generate-load.sh 10

# Observa queue size
curl -s localhost:8888/metrics | grep otelcol_exporter_queue_size

# Reinicia el Collector; la cola persiste
docker compose restart collector
sleep 5

# Queue size NO es 0 tras restart (persistente)
curl -s localhost:8888/metrics | grep otelcol_exporter_queue_size

# Levanta el backend; la cola se vacía
docker compose start backend
sleep 10
curl -s localhost:8888/metrics | grep otelcol_exporter_queue_size   # debe bajar a 0

docker compose logs backend | tail -20   # muestra los spans entregados
```

## Validación automatizada

```bash
bash files/verify.sh
```

## Puntos clave

- `file_storage.directory: /var/lib/otelcol/queue` montado desde `/tmp/otel13-ex02/queue` (bind mount persistente).
- `sending_queue.storage: file_storage` — sin esto la cola es memoria pura.
- `memory_limiter` con `limit_mib: 256` y `spike_limit_mib: 64`; si pisamos el límite, el receiver devuelve error al cliente — backpressure propagada.
- `retry_on_failure.max_elapsed_time: 0` → reintentar indefinidamente mientras la cola tenga espacio.

## Limpieza

```bash
bash files/clean.sh
```
