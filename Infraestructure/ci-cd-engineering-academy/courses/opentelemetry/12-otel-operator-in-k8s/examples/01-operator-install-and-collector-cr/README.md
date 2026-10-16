# Ejemplo 01 — Instalar el OTel Operator y aplicar un `OpenTelemetryCollector`

Instala **cert-manager** + **OpenTelemetry Operator** en un cluster `kind`, aplica un CR `OpenTelemetryCollector` en modo `deployment`, y verifica que el Operator reconcilia el ConfigMap, Deployment y Service.

## Archivos

- `demo.sh` — flujo end-to-end idempotente; crea el cluster, instala, aplica el CR, verifica, limpia.
- `collector-deployment.yaml` — CR `OpenTelemetryCollector` mode `deployment` con un pipeline mínimo (`otlp → batch → debug`).

## Qué observar

1. Qué CRDs aparecen tras instalar el Operator (`opentelemetrycollectors`, `instrumentations`, `opampbridges`).
2. Qué objetos genera el CR: `ConfigMap`, `Deployment`, `Service`, `ServiceAccount`.
3. La config renderizada en el ConfigMap es `spec.config` serializado — no la editas: editas el CR.
4. Qué pasa si borras el `Deployment` generado (el Operator lo recrea).

## Requisitos

`kind`, `kubectl`. Internet para pulls (cert-manager y Operator manifests + images).

Si falta alguno, el script sale con `SKIP:` y código 0 (no es un error en CI "lightweight").

## Ejecutar

```bash
bash demo.sh                # ejecutar y limpiar
KEEP=1 bash demo.sh         # dejar el cluster vivo para explorar
```

## Limpieza

Automática al salir. Para forzar: `kind delete cluster --name otel-12-ex01`.
