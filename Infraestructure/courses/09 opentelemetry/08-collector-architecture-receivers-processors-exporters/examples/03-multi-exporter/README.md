# Ejemplo 03 — Multi-exporter (fan-out)

## Objetivo

Mostrar como una **misma pipeline** envia los mismos datos a **dos exporters** a la vez. Es el patron usado para:

- **Migrar de backend** (dev + prod en paralelo, comparar, cortar el viejo).
- **Observar y archivar** (debug/file para visibilidad local, backend real para produccion).
- **Multi-tenant / multi-region** (envio simultaneo a dos destinos).

## Que hace esta config

La pipeline `traces` recibe por OTLP y abanica a:

1. `debug` — imprime en stdout (visibilidad humana).
2. `file` — escribe JSON lines a `/tmp/otel-out/traces.jsonl` dentro del Collector (archivado barato, util para tests).

Lo mismo con `metrics` y `logs` (archivos separados).

## Archivos

- `config.yaml`
- Diagrama:

```
         +--------- Collector ---------+
OTLP --> | traces  --> [debug]         |
         |          --> [file (jsonl)] |
         +-----------------------------+
```

## Validar

```sh
docker run --rm \
  -v "$PWD/config.yaml:/etc/otelcol/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:latest \
  validate --config=/etc/otelcol/config.yaml
```

## Correrlo (opcional)

```sh
mkdir -p /tmp/otel-out
docker run --rm \
  -p 4317:4317 -p 4318:4318 \
  -v "$PWD/config.yaml:/etc/otelcol/config.yaml:ro" \
  -v /tmp/otel-out:/tmp/otel-out \
  otel/opentelemetry-collector-contrib:latest \
  --config=/etc/otelcol/config.yaml
```

Al mandar telemetria veras:

- Spans en los logs del Collector (debug).
- `/tmp/otel-out/traces.jsonl` creciendo (file).

## Costo del fan-out

Cada exporter adicional **duplica el trafico de salida**. Util puntualmente; caro de default. En produccion se usa:

- 1 exporter al backend principal.
- 1 exporter secundario solo durante migracion / troubleshooting / canarios.
