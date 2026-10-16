# otel-14-02 — Switch vendor exercise

## 1. Identificación

- **ID:** `otel-14-02-switch-vendor-exercise`
- **Tecnología:** opentelemetry
- **Módulo:** `14-platform-patterns-vendor-neutral-cost-and-semconv-governance`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

El capstone del curso emite OTLP a un Collector local que exporta a **Tempo** (traces), **Prometheus** (métricas vía `prometheusremotewrite`) y **Loki** (logs vía `otlphttp`). La dirección decidió evaluar **Datadog** como backend único durante un trimestre. Debes demostrar que el cambio es **sólo** de configuración del Collector — ni una línea en `src/`.

El `starter/` incluye una estructura de proyecto reducida con `src/` (ficticio, representa el capstone), `collector/collector-self-hosted.yaml` (Tempo+Loki+Prometheus) y archivos de contrato. Tu entrega: `collector/collector-datadog.yaml` + `collector/MIGRATION.md`.

## 3. Objetivos

- Producir `collector-datadog.yaml` que use el exporter `datadog` para los 3 signals.
- Mantener todos los processors de cost control (tail sampling, drop high-card, batch, memory_limiter).
- Credenciales referenciadas por variable de entorno (`${DD_API_KEY}`), nunca literal.
- Redactar `MIGRATION.md` con contexto, pasos, rollback y verificación.
- Pasar `tests/validate.sh`.

## 4. Prerrequisitos

- Haber completado `otel-14-01` y `otel-11-01`.
- `bash`, `python3`, `pyyaml` (`pip install pyyaml`).
- Un editor de texto. Sin coste (no se contacta realmente a Datadog).

## 5. Instrucciones

1. Prepara scratch:

   ```bash
   rm -rf /tmp/otel-14-02
   mkdir -p /tmp/otel-14-02
   cp -r activities/02-switch-vendor-exercise/starter/* /tmp/otel-14-02/
   cd /tmp/otel-14-02
   ```

2. Inspecciona `src/` y `collector/collector-self-hosted.yaml`. Fíjate que `src/` es ficticio y no debe cambiarse.

3. Crea `collector/collector-datadog.yaml` basándote en el self-hosted:
   - Mismos receivers (OTLP gRPC + HTTP).
   - Mismos processors (memory_limiter, batch, k8sattributes, tail_sampling, attributes/drop-high-card, resource).
   - **Reemplaza** los tres exporters por un único exporter `datadog` (soporta las 3 signals) usando `${env:DD_API_KEY}` y `${env:DD_SITE}`.
   - Pipelines `traces`, `metrics`, `logs` apuntan al exporter `datadog`.

4. Crea `collector/MIGRATION.md` con las secciones: Context, Decision, Steps, Verification, Rollback.

5. Valida:

   ```bash
   bash activities/02-switch-vendor-exercise/tests/validate.sh /tmp/otel-14-02
   ```

6. Smoke manual: corre el validador **dos veces seguidas**; ambas deben pasar.

## 6. Resultado esperado

- `/tmp/otel-14-02/collector/collector-datadog.yaml` existe y es YAML válido.
- Usa exporter `datadog` y referencia `${env:DD_API_KEY}` (sin literales).
- Conserva los processors de cost control.
- `/tmp/otel-14-02/collector/MIGRATION.md` tiene las 5 secciones requeridas.
- El validador compara archivos bajo `src/`: deben estar **idénticos** al starter (hash igual).

## 7. Criterios de aceptación

| Dimensión | Criterio |
| --- | --- |
| Funcionalidad | YAML válido, exporter `datadog` configurado para los 3 signals. |
| Seguridad | API key sólo vía variable de entorno; nunca literal. |
| Reproducibilidad | Validador OK dos veces seguidas. |
| Mantenibilidad | MIGRATION.md incluye plan de rollback. |
| Neutralidad | Zero cambios bajo `src/`. |

## 8. Validación

```bash
bash activities/02-switch-vendor-exercise/tests/validate.sh /tmp/otel-14-02
```

## 9. Preguntas de reflexión

- Si el equipo decidiera volver a self-hosted en 3 meses, ¿qué cambia? ¿Y si quisiera mantener **ambos** backends en paralelo?
- ¿Qué atributos específicos de Datadog (`host`, `env`, `service`) usa el exporter y cómo se derivan del Resource OTel? ¿Introduce esto lock-in?
- ¿Qué pasa con los dashboards de Grafana existentes? ¿Es parte del "switch sin tocar código"?
- Si el exporter `datadog` fallara (API down), ¿qué hace el Collector? ¿Cómo lo preparas (sending_queue, retry)?

## 10. Extensiones

- Añadir multi-export (Datadog + Tempo simultáneos) para shadow mode durante 2 semanas.
- Añadir un segundo `collector-honeycomb.yaml` para demostrar que la neutralidad vale para N vendors.
- Documentar los dashboards de Grafana que requieren portado a Datadog Monitors.

## 11. Limpieza

```bash
rm -rf /tmp/otel-14-02
```
