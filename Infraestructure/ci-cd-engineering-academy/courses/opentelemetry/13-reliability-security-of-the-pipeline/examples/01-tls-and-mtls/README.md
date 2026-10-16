# Ejemplo 01 — TLS y mTLS entre agent y gateway

## Concepto que demuestra

El Collector gateway expone OTLP primero con **TLS server-side** (cliente verifica cert del server, el server no verifica al cliente), luego sube a **mTLS** (ambos presentan cert). Verás que `insecure_skip_verify: false` falla cuando el cert no es confiable y por qué `client_ca_file` en el receiver es lo que hace mTLS.

## Contexto

Materializa §2 y §3 de la lección. Genera una CA self-signed, firma dos certs (uno para el server/gateway, otro para el cliente/agent) y arranca un `docker compose` con dos Collectors.

## Prerrequisitos

- `docker` + `docker compose`.
- `openssl` (`openssl version`). Si no está, `bootstrap.sh` imprime `SKIP` y sale sin error.
- Imagen `otel/opentelemetry-collector-contrib:0.110.0` (se baja sola).

## Archivos

- `files/bootstrap.sh` — genera CA + server cert + client cert con OpenSSL en `/tmp/otel13-ex01/certs/`.
- `files/docker-compose.yaml` — levanta `gateway` y `agent`.
- `files/gateway-tls.yaml` — gateway con TLS server-side.
- `files/gateway-mtls.yaml` — gateway con mTLS.
- `files/agent-tls.yaml` — agent exportando con TLS (sin client cert).
- `files/agent-mtls.yaml` — agent exportando con mTLS (con client cert).
- `files/verify.sh` — ejecuta el flujo completo.
- `files/clean.sh` — baja todo y borra `/tmp/otel13-ex01/`.

## Paso 1 — Generar certs

```bash
bash files/bootstrap.sh
ls /tmp/otel13-ex01/certs/
# ca.crt ca.key server.crt server.key client.crt client.key
```

## Paso 2 — TLS server-side

```bash
cd files
cp gateway-tls.yaml  /tmp/otel13-ex01/gateway.yaml
cp agent-tls.yaml    /tmp/otel13-ex01/agent.yaml
docker compose -f docker-compose.yaml up -d
sleep 5
docker compose -f docker-compose.yaml logs gateway | tail -20
# Deberías ver: "Everything is ready. Begin running and processing data."
docker compose -f docker-compose.yaml logs agent | tail -20
# El agent emite "debug" spans y los exporta a gateway con TLS verified.
```

Rompe el server cert (edita `files/agent-tls.yaml` y pon un `ca_file` inexistente) y verifica que el agent falla con `x509: certificate signed by unknown authority`.

## Paso 3 — mTLS

```bash
cp gateway-mtls.yaml /tmp/otel13-ex01/gateway.yaml
cp agent-mtls.yaml   /tmp/otel13-ex01/agent.yaml
docker compose -f docker-compose.yaml restart
sleep 5
docker compose -f docker-compose.yaml logs gateway | tail -10
# Si quitas client cert del agent, verás "tls: client didn't provide a certificate"
```

Prueba manual con `curl` (debe FALLAR porque curl no presenta client cert):

```bash
curl -k --cacert /tmp/otel13-ex01/certs/ca.crt \
  https://localhost:4318/v1/traces -d '{}'
# -> "tls: client didn't provide a certificate"
```

Con client cert (debe pasar la capa TLS; el 400 posterior es por payload vacío, lo cual demuestra que llegó):

```bash
curl -k --cacert /tmp/otel13-ex01/certs/ca.crt \
  --cert /tmp/otel13-ex01/certs/client.crt \
  --key  /tmp/otel13-ex01/certs/client.key \
  https://localhost:4318/v1/traces -d '{}'
# -> 400 Bad Request (payload inválido pero autenticado)
```

## Validación automatizada

```bash
bash files/verify.sh
```

Debe terminar con `== OK: TLS server-side y mTLS verificados ==`.

## Limpieza

```bash
bash files/clean.sh
```
