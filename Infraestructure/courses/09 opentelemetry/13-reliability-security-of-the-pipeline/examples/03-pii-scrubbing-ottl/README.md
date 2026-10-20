# Ejemplo 03 — PII scrubbing con `attributes`, `redaction` y OTTL

## Concepto que demuestra

Tres capas de defensa:

1. **`attributes` processor** — hash o delete sobre llaves conocidas (`user.email`, `http.request.header.authorization`).
2. **`redaction` processor** — regex sobre valores (números de tarjeta).
3. **`transform` + OTTL** — reglas más expresivas (p. ej. email dentro de `http.url`, redacción de query params `token=`).

Materializa §10 y §11 de la lección.

## Prerrequisitos

- `docker` + `docker compose`.
- Imagen `otel/opentelemetry-collector-contrib:0.110.0`.

## Archivos

- `files/docker-compose.yaml` — un solo Collector; exporter `debug` muestra el output.
- `files/collector.yaml` — tres processors de scrubbing encadenados.
- `files/push-pii-spans.sh` — envía spans con PII simulada vía `telemetrygen` + atributos custom.
- `files/verify.sh` — produce spans con PII y comprueba que el output NO los contiene literalmente.
- `files/clean.sh` — limpieza.

## Flujo

```bash
cd files
docker compose up -d
sleep 4

# Enviar spans con PII plantada
bash push-pii-spans.sh

# Ver salida: los atributos sensibles aparecen hasheados / redactados / eliminados
docker logs otel13-ex03-collector | tail -60
```

## Qué verás en la salida

- `user.email: 7b3f8c...` (hash SHA-256 en vez del valor).
- `user.password` — ausente (deleted).
- `http.request.header.authorization: [REDACTED]`.
- `credit_card: [CARD]` (reemplazado por regex OTTL).
- `url.query` con `token=[REDACTED]` en vez de `token=abc123`.

## Validación automatizada

```bash
bash files/verify.sh
```

Falla si cualquier PII plantado aparece literal en los logs del Collector.

## Limpieza

```bash
bash files/clean.sh
```
