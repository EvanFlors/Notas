# Ejemplo 01 — FastAPI auto-instrumentation (`opentelemetry-instrument`)

Levanta una app FastAPI mínima **sin tocar código de instrumentación**: el wrapper CLI `opentelemetry-instrument` carga las `opentelemetry-instrumentation-*` presentes y configura un TracerProvider que exporta a consola.

## Requisitos

```bash
pip install \
  fastapi uvicorn httpx \
  opentelemetry-distro opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-fastapi \
  opentelemetry-instrumentation-httpx
```

Nota: si no están los `opentelemetry-instrumentation-*`, el script hace `SKIP` limpio.

## Correr

```bash
cd $(dirname "$0")
bash run.sh
```

El script:
1. Verifica deps y hace SKIP si faltan.
2. Lanza la app con `opentelemetry-instrument` configurando `ConsoleSpanExporter`.
3. Hace `curl /health` y `curl /work`.
4. Mata la app y muestra las primeras líneas del log; verifica que aparecen spans con `name` tipo `GET /health`.

## Qué observar

- Spans **SERVER** emitidos por FastAPIInstrumentor (uno por request).
- Atributos semconv HTTP: `http.request.method`, `http.response.status_code`, `url.path`, `http.route`.
- Resource `service.name=example-01-auto` (via `--service_name`).
- Sin una sola línea de setup en `app.py`.

## Decisiones

- `ConsoleSpanExporter` evita depender de un Collector local.
- Service name se pasa por flag al wrapper, no hardcoded en código — así cambia por entorno sin rebuild.
