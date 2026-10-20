# Ejercicio operativo — Instrumentación Python + Collector local

## Requisitos del entorno

- Python 3.11+ con `pip`.
- `otelcol-contrib` v0.100+ en el PATH (binario oficial de `open-telemetry/opentelemetry-collector-releases`).
- `jq` para la validación.
- Puertos libres: `4317` (OTLP gRPC) y `8000` (FastAPI).

Si **cualquiera** de estos requisitos no puede cumplirse en tu entorno, declara **SKIP** en `answers.md` y el bloque operativo se descontará proporcionalmente.

## Instalación

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
opentelemetry-bootstrap -a install   # instala instrumentations detectadas
mkdir -p out
```

## Ejecución

En una terminal:

```bash
otelcol-contrib --config otel-collector-config.yaml 2>&1 | tee run.log
```

En otra terminal:

```bash
export OTEL_SERVICE_NAME=checkout
export OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,deployment.environment=exam
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
opentelemetry-instrument uvicorn app:app --host 0.0.0.0 --port 8000
```

Dispara requests:

```bash
curl -s "http://localhost:8000/checkout/ord-123?items=4&payment=card"
curl -s "http://localhost:8000/checkout/fail?items=2&payment=paypal"
```

Detén el Collector (`Ctrl+C`) para que `out/traces.json` se flushee.

## Validación

```bash
./validate.sh
```

Los 5 checks deben imprimir `OK`.

## Entregables

- `app.py` instrumentado.
- `otel-collector-config.yaml` completo.
- `out/traces.json`.
- `run.log`.
