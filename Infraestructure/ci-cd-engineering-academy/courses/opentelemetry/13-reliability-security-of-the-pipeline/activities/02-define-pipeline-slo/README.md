# otel-13-02 — Definir SLOs del pipeline OTel

## 1. Identificación

- **ID:** `otel-13-02-define-pipeline-slo`
- **Tecnología:** opentelemetry
- **Módulo:** `13-reliability-security-of-the-pipeline`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** independent

## 2. Contexto

El pipeline no solo observa — es *él mismo* un sistema que debe tener SLOs. "El Collector debería andar bien" no es un SLO. "99.9% de uptime mensual, p99 latencia end-to-end agent→backend < 2s, drop rate < 0.1% medido en ventana de 1h" sí lo es. Esta actividad te hace definirlos **por ti mismo**, con las métricas `otelcol_*` reales como SLIs, y escribir alertas que disparan al quemar error budget.

No hay solución única "correcta"; hay solución *coherente*: los SLIs eligen SLOs razonables, los SLOs permiten derivar error budget, el budget derivado implica reglas de alerta cuantificadas, las alertas vinculan a playbooks concretos. El validador comprueba estructura (secciones completas, reglas sintácticamente válidas, SLIs referencian métricas reales), no las cifras exactas.

## 3. Objetivos

Al terminar debes poder:

- Elegir SLIs medibles usando métricas `otelcol_*` sin inventarse métricas que no existen.
- Diferenciar SLI (lo que mides), SLO (el objetivo), SLA (el contrato comercial), error budget (lo que puedes gastar).
- Escribir reglas Prometheus con `rate()` y `increase()` sobre ventanas razonables.
- Justificar cada decisión numéricamente (por qué 99.9 y no 99.99, por qué p99 y no p95).

## 4. Prerrequisitos

- Haber terminado la Actividad 01 (y entender la métrica `otelcol_*`).
- Lectura previa de "SRE Workbook" cap. 2 (opcional pero recomendado).

## 5. Instrucciones

Crea `/tmp/otel13-act02/SLO.md` y `/tmp/otel13-act02/alerts.yaml` cumpliendo lo siguiente:

### `SLO.md` — debe tener estas 5 secciones (títulos exactos):

```
## SLIs
## SLOs
## Error Budget
## Alertas
## Playbook
```

Contenido mínimo requerido por sección:

- **`## SLIs`** — al menos **tres** SLIs. Cada uno con: nombre, pregunta que responde, métrica Prometheus que lo computa (debe empezar por `otelcol_` o derivar de ella). Ejemplos de dirección: *availability* (uptime del gateway), *freshness* (latencia end-to-end), *loss* (drop rate), *saturation* (queue size vs capacity).
- **`## SLOs`** — para cada SLI, un objetivo cuantificado con ventana (p. ej. "99.9% medido mensualmente"). Al menos tres SLOs.
- **`## Error Budget`** — cálculo del budget mensual (en minutos de downtime, o en número de spans "permitidamente perdidos"). Dos escenarios ilustrativos (quema lenta vs rápida).
- **`## Alertas`** — texto que describe las alertas y referencia el archivo `alerts.yaml`. Mínimo tres alertas (ej.: fast burn, slow burn, saturation).
- **`## Playbook`** — qué hacer cuando dispara cada alerta. Debe mencionar al menos dos acciones concretas (p. ej. "verificar `otelcol_exporter_send_failed_spans`", "escalar el `queue_size`", "rollback a versión N-1 del Collector").

### `alerts.yaml` — reglas Prometheus válidas

- Debe ser YAML válido con top-level `groups:`.
- Al menos **tres** reglas en `rules:`.
- Cada regla con `alert`, `expr`, `for`, `labels`, `annotations`.
- `expr` debe referenciar al menos una métrica que empiece por `otelcol_`.

Ejemplo mínimo de forma (no la copies tal cual; adáptala):

```yaml
groups:
  - name: otel-pipeline-slo
    rules:
      - alert: PipelineFastBurn
        expr: ...
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "..."
          runbook: "..."
```

## 6. Resultado esperado

- `/tmp/otel13-act02/SLO.md` con las 5 secciones y contenido mínimo arriba.
- `/tmp/otel13-act02/alerts.yaml` con ≥ 3 reglas válidas referenciando métricas `otelcol_*`.

## 7. Criterios de aceptación

- Las 5 secciones existen con los títulos exactos.
- ≥ 3 SLIs mencionando métricas `otelcol_*`.
- ≥ 3 reglas Prometheus parseables (`yamllint` opcional; el validador usa Python).
- Cada regla alertante referencia una métrica `otelcol_*` en `expr`.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué un SLO de 99.99% es casi siempre un error para un sistema interno de observabilidad?
2. ¿Qué distingue "drop por `memory_limiter`" (esperado bajo spike) de "drop por `send_failed`" (siempre malo)?
3. Si tu SLO de freshness es p99 < 2s pero `batch.timeout` es 500ms, ¿qué debería ser la mayor contribución a los 1.5s restantes?
4. ¿Qué pasa con el error budget si durante una ventana el Collector drop 100% de los datos durante 2 min? ¿Deberías pausar deploys?
5. ¿Puede tu propio sistema de alertas (Prometheus + Alertmanager) depender del mismo Collector? ¿Qué cambia?

## 10. Extensiones

- Usa [slo-generator](https://github.com/google/slo-generator) para derivar burn-rate alerts canónicas.
- Añade un SLO *por tenant* (si usas multi-tenancy).
- Dibuja la cadena de causalidad: SLI violado → playbook → acción → métrica de recuperación.

## 11. Limpieza

```bash
rm -rf /tmp/otel13-act02/
```
