# 01 — FastAPI client + server with continuous trace

Dos procesos FastAPI (A y B) exportan spans a `ConsoleSpanExporter`. El cliente A hace `httpx.get` a B; con las instrumentations oficiales activas, el `traceparent` viaja automáticamente y ambos spans comparten `trace_id`.

## Requisitos

```
pip install fastapi uvicorn httpx \
            opentelemetry-sdk \
            opentelemetry-instrumentation-fastapi \
            opentelemetry-instrumentation-httpx
```

Si falta algún paquete, el script `run.sh` imprime `SKIP` y sale 0.

## Cómo correrlo

```bash
bash run.sh
```

Deberías ver en los logs dos spans con el **mismo** `trace_id` y el span de A como parent del span de B (`parent_id` de B == `span_id` del server span de A o del client span intermedio).

## Qué observar

- Sin tocar propagators (W3C es default), la cadena ya funciona.
- Si comentas `HTTPXClientInstrumentor().instrument()` en `client.py`, los dos trace_ids se vuelven distintos: el carrier nunca se inyecta.
- Si comentas `FastAPIInstrumentor.instrument_app(app)` en `server.py`, el server no hace `extract` y arranca un trace nuevo.
