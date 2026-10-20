# Actividad 01 — Collector local recibiendo las 3 signals

## 1. Identificacion

- **ID:** `otel-08-01-collector-local-with-three-signals`
- **Tecnologia:** opentelemetry
- **Modulo:** 08-collector-architecture-receivers-processors-exporters
- **Dificultad:** intermediate
- **Duracion estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

En produccion rara vez montas el Collector sin verlo primero funcionando localmente con las 3 signals. Esta actividad te hace levantar un Collector `otelcol-contrib` en Docker, mandarle traces, metrics y logs sinteticas con `telemetrygen` (herramienta oficial del proyecto) y verificar que las 3 pipelines escriben a archivos JSON lines con el `file` exporter. Es el "hello world" del Collector y el patron que uses despues para troubleshooting.

## 3. Objetivos

- Levantar `otelcol-contrib` en Docker con una config que tiene las 3 pipelines (`traces`, `metrics`, `logs`).
- Emitir las 3 signals via OTLP gRPC usando `telemetrygen`.
- Verificar que los 3 archivos de salida (`traces.jsonl`, `metrics.jsonl`, `logs.jsonl`) existen y contienen datos.
- Interpretar la salida del `debug` exporter para troubleshooting.

## 4. Prerrequisitos

- **Conocimientos:** YAML, Docker basico, lectura de JSON.
- **Software:** `docker` corriendo (sino, el `validate.sh` reporta SKIP). `bash`, `jq` (opcional, mejora la lectura).
- **Infra:** nada mas; todo es local.
- **Puertos:** `4317` (OTLP gRPC) y `4318` (OTLP HTTP) libres en localhost.
- **Costos:** cero.
- **Imagenes Docker usadas:**
  - `otel/opentelemetry-collector-contrib:latest`
  - `ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest`

## 5. Instrucciones

1. Lee `starter/config.yaml` — es la config base: 3 pipelines, `otlp` receiver, `debug` + `file` exporters.
2. Lanza el Collector:
   ```sh
   bash starter/run-collector.sh
   ```
   Deja esa terminal abierta (muestra los logs del Collector).
3. En otra terminal, lanza los generadores de traces, metrics y logs:
   ```sh
   bash starter/send-signals.sh
   ```
4. Inspecciona los archivos de salida:
   ```sh
   ls -lh /tmp/otel-lab/
   head -c 500 /tmp/otel-lab/traces.jsonl
   ```
5. Detén el Collector (`Ctrl-C` en su terminal o `docker rm -f otel-lab-collector`).
6. Opcional: valida con el binario:
   ```sh
   docker run --rm -v "$PWD/starter/config.yaml:/c.yaml:ro" \
     otel/opentelemetry-collector-contrib:latest validate --config=/c.yaml
   ```

## 6. Resultado esperado

- Los logs del Collector muestran lineas tipo:
  ```
  info TracesExporter {"resource spans": N, "spans": M}
  info MetricsExporter {"resource metrics": N, "metrics": M}
  info LogsExporter {"resource logs": N, "log records": M}
  ```
- Existen `/tmp/otel-lab/traces.jsonl`, `/tmp/otel-lab/metrics.jsonl`, `/tmp/otel-lab/logs.jsonl` con contenido no vacio.

## 7. Criterios de aceptacion

- `otelcol-contrib validate` pasa sobre `starter/config.yaml`.
- Los 3 archivos `.jsonl` existen y contienen al menos un objeto JSON cada uno.
- La config respeta orden: `memory_limiter` primero, `batch` ultimo.

## 8. Validacion

```sh
bash tests/validate.sh
```

El script levanta el collector, envia las 3 signals, verifica los archivos y limpia todo. Si docker no esta disponible, reporta `SKIP` con exit code 0.

## 9. Preguntas de reflexion

1. Por que una pipeline por signal y no una unica?
2. Que pasaria si quitaras `memory_limiter` y el productor te enviase 1M spans/s?
3. Como adaptar la config para enviar a Tempo (traces) + Prometheus (metrics) + Loki (logs) en vez de a archivos?
4. Que te dice el `debug` exporter que el `file` exporter no?

## 10. Extensiones

- Reemplazar `file` por `otlphttp` apuntando a un endpoint simulado (`httpbin` o `ngrok`).
- Anadir una segunda pipeline `traces/sampled` con tail_sampling y comparar los jsonl.
- Levantar un Tempo local y mandar traces reales.

## 11. Limpieza

```sh
docker rm -f otel-lab-collector 2>/dev/null || true
rm -rf /tmp/otel-lab
```
