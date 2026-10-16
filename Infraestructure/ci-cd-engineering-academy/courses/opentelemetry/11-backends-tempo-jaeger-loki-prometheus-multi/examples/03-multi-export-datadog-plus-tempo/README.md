# Ejemplo 03 — Multi-export: Tempo (self-hosted) + Datadog (vendor)

**Walkthrough-only si no hay `DD_API_KEY`.** El objetivo del ejemplo es demostrar el patrón de **fan-out** del Collector: un mismo pipeline `traces` manda a dos backends en paralelo. En este caso, Tempo (que corre localmente) y Datadog APM (vendor, requiere token real).

## Qué muestra

- Un único pipeline `traces` en el Collector con **dos exporters**:
  - `otlp/tempo` → `tempo:4317` (self-hosted).
  - `datadog` → el intake de Datadog (`${env:DD_SITE}` por región).
- `DD_API_KEY` se inyecta por variable de entorno; **nunca** se escribe en el YAML comiteado.
- Útil para migraciones blue/green o para evaluar un vendor sin perder la salida actual.

## SIN DD_API_KEY — modo walkthrough

Si no tienes un token real de Datadog, el stack arranca igualmente **pero el exporter de Datadog devolverá 403**. Lo verás en los logs del Collector como `datadog exporter: Unauthorized` o `send_failed_spans`. **Esto es esperado y aceptable para el ejercicio**: lo que se demuestra es el patrón de fan-out, no la integración real con Datadog.

El `check.sh` detecta la ausencia de la variable y marca ese caso como `SKIP (vendor leg)`.

## CON DD_API_KEY

```bash
export DD_API_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export DD_SITE="datadoghq.com"           # o datadoghq.eu, etc.
docker compose up -d
```

Después de ~2 min deberías ver los traces de `trace-gen` tanto en Grafana (`http://localhost:3000` → Explore → Tempo) como en tu cuenta Datadog APM.

## Archivos

- `docker-compose.yaml` — Tempo + Collector + Grafana + trace-gen.
- `otel-collector-config.yaml` — pipeline con fan-out.
- `check.sh` — smoke test: verifica Tempo recibe, reporta estado del vendor leg.

## Advertencia

NUNCA comitees `DD_API_KEY`. Si lo haces por accidente, rótalo inmediatamente en tu cuenta Datadog.

## Limpieza

```bash
docker compose down -v
unset DD_API_KEY DD_SITE
```
