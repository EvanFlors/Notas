# Ejemplo 01 — Esqueleto YAML del Collector

## Objetivo

Mostrar el YAML minimo valido para un Collector con las **tres pipelines** (traces, metrics, logs), un unico receiver `otlp` y un unico exporter `debug` (stdout).

## Archivos

- `config.yaml` — la configuracion.

## Como leerlo

1. Bloques declarativos: `receivers`, `processors`, `exporters` definen el catalogo.
2. Bloque `service.pipelines.<signal>` referencia componentes por nombre.
3. `memory_limiter` va **primero** en cada pipeline; `batch` va **ultimo**.
4. `service.telemetry.logs.level: info` controla la verbosidad del propio Collector.

## Validar la config

Con el binario `otelcol-contrib` instalado:

```sh
otelcol-contrib validate --config=config.yaml
```

Con Docker (sin instalar nada):

```sh
docker run --rm \
  -v "$PWD/config.yaml:/etc/otelcol/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:latest \
  validate --config=/etc/otelcol/config.yaml
```

## Como correrlo (opcional)

```sh
docker run --rm \
  -p 4317:4317 -p 4318:4318 \
  -v "$PWD/config.yaml:/etc/otelcol/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:latest \
  --config=/etc/otelcol/config.yaml
```

Luego cualquier SDK apuntando a `localhost:4317` (gRPC) o `localhost:4318` (HTTP) empezara a imprimir en los logs del Collector gracias al `debug` exporter.

## Lecciones

- **Simetria por signal**: una pipeline por cada una, aun si el pipeline es casi identico.
- **`debug` exporter** es el amigo del troubleshooting; en produccion se saca o se baja a `verbosity: basic`.
- Un YAML sin `memory_limiter` arranca pero es peligroso en produccion; aqui va desde el minuto cero.
