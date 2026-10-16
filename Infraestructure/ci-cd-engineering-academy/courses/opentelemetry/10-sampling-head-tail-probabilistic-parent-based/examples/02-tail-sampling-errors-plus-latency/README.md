# Ejemplo 02 — Tail sampling: errores + latencia + probabilistic

Levanta un **OTel Collector contrib** con el processor `tail_sampling` configurado para:

- 100% de los traces con cualquier span `ERROR`.
- 100% de los traces con span root cuya `latency > 500 ms`.
- 10% probabilistic de los éxitos cortos restantes.

Luego, un generador Python emite 300 traces mezclados (fast ok, slow ok, errors). Verificamos que el Collector exporta aproximadamente los esperados a su exporter `file` (`/tmp/otel10-tail-out.json`).

## Requisitos

- Docker 20+ (para `otel/opentelemetry-collector-contrib`).
- Python 3.10+ con `pip install -r requirements.txt`.

Si no hay Docker, el script `smoke.sh` sale con mensaje `SKIP: docker no disponible` y exit 0.

## Correr

```bash
cd examples/02-tail-sampling-errors-plus-latency/
./smoke.sh
```

El script:

1. Verifica Docker.
2. Levanta Collector (puerto `4317` OTLP gRPC) con `collector-config.yaml`.
3. Instala deps Python en venv temporal.
4. Ejecuta `load.py` que genera 300 traces (150 fast ok, 100 slow ok, 50 errors).
5. Espera `decision_wait + 2s`.
6. Cuenta traces en `/tmp/otel10-tail-out.json`.
7. Verifica rangos: errors == 50, slow == 100, fast ok ~= 15 (10%).
8. Para contenedor y limpia.

## Qué observar

- El Collector es `otel/opentelemetry-collector-contrib:0.108.0` (el **contrib** incluye `tail_sampling`; el core no).
- `decision_wait: 5s` para que el smoke test sea rápido (en producción: 10–30 s).
- Los exporters son `file` para inspección trivial y `debug` para logs.
- Las policies son **OR**: cualquiera que marque SAMPLED gana.

## Limpieza

El propio `smoke.sh` hace `docker rm -f` y limpia `/tmp/otel10-tail-*`.
