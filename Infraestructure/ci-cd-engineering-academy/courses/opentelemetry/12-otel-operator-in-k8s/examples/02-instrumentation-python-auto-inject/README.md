# Ejemplo 02 — `Instrumentation` CR + auto-inject de Python

Muestra el camino *zero-code*: aplicar un `Instrumentation` CR, desplegar un Pod Python anotado con `instrumentation.opentelemetry.io/inject-python=true` y observar qué inyecta el webhook del Operator (initContainer `opentelemetry-auto-instrumentation-python`, env vars `OTEL_*`, mount del SDK en `/otel-auto-instrumentation-python`).

## Archivos

- `demo.sh` — crea kind, instala cert-manager + Operator, aplica un gateway Collector, el `Instrumentation`, y un Deployment Python anotado; muestra la mutación.
- `instrumentation.yaml` — CR `Instrumentation` apuntando al gateway.
- `python-app.yaml` — Deployment mínimo con `python:3.12-slim` ejecutando un servidor HTTP; anotado para auto-inject.

## Qué observar

1. El Pod original tenía 1 container; tras la mutación tiene 1 container + 1 initContainer.
2. El container de la app no cambia su image, pero gana env vars `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `PYTHONPATH`, `OTEL_RESOURCE_ATTRIBUTES` con `k8s.*`.
3. Un volumen `emptyDir` compartido entre el initContainer y el app container contiene el SDK.
4. En los logs del gateway Collector (exporter `debug`) aparecen spans tras unas peticiones HTTP.

## Requisitos

`kind` + `kubectl`. Si falta alguno, el script sale con `SKIP:`.

## Ejecutar

```bash
bash demo.sh
```

## Limpieza

Automática. `KEEP=1 bash demo.sh` para dejarlo vivo.
