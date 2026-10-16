# Ejemplo 02 — Resource + Semconv HTTP v1

## Concepto que demuestra

Construir un payload "a mano" que respeta a la vez:

- Un bloque **Resource** correcto (`service.name`, `service.version`, `deployment.environment`, `host.*`, `k8s.*`).
- Un conjunto de **span attributes** siguiendo semconv **HTTP v1** (los nombres **nuevos**: `http.request.method`, `http.response.status_code`, `url.full`, `server.address`).

## Contexto

Antes de instrumentar código real (eso llega en `otel-04`), conviene **ver con los ojos** cómo se vería un span bien formado. Esto te da el modelo mental para auditar lo que tu SDK emite.

## Objetivo

- Distinguir Resource vs span attributes.
- Memorizar los nombres **actuales** (post-migración) de semconv HTTP.
- Reconocer un contra-ejemplo con nombres **viejos** (deprecados).

## Prerrequisitos

- `python3`. **SKIP si no está.**

## Ejecución

```bash
cd "$(git rev-parse --show-toplevel)/courses/opentelemetry/02-specification-semconv-and-context-propagation/examples/02-resource-and-semconv"
bash run.sh
```

Salida esperada (abreviada): un JSON con dos spans de ejemplo (uno con semconv **nuevo** y uno con el **viejo**), con una nota explicando qué atributos están deprecados en el segundo.

## Qué está pasando por debajo

El script genera dos documentos JSON representando dos spans del mismo tipo (petición HTTP). El primero usa:

- Resource: `service.name=orders-api`, `service.version=1.4.2`, `deployment.environment=production`, `host.name=node-7`, `k8s.pod.name=orders-api-abc123`.
- Attributes: `http.request.method`, `http.response.status_code`, `url.full`, `url.path`, `server.address`.

El segundo usa los nombres **viejos** (`http.method`, `http.status_code`, `http.url`, `http.target`, `http.host`) y el script los marca como `DEPRECATED`.

Esto no se envía por OTLP; se imprime, para que puedas leerlo. Si quieres el equivalente real en wire, el SDK lo serializa a `protobuf` según `opentelemetry-proto`.

## Limpieza

Nada que limpiar.
