# obs-14-02 — Adopta Sloth y compara con las reglas escritas a mano (independent)

## 1. Identificación
- **ID:** `obs-14-02-adopt-sloth`
- **Tecnología:** prometheus-grafana
- **Módulo:** `14-slo-and-burn-rate-alerts`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto
Mantener MWMBR a mano escala mal: cada SLO nuevo requiere ~15 recording rules + 2 alertas con fórmulas repetidas. [Sloth](https://sloth.dev/) resuelve ese problema generando el `PrometheusRule` desde una spec YAML concisa. En esta actividad usarás Sloth para generar las reglas de la API `payments` y compararás con la versión hecha a mano en la actividad anterior.

## 3. Objetivos
- Escribir una spec Sloth (`slo.yaml`) para el SLO `payments-availability` 99.9 %.
- Generar el `PrometheusRule` con `sloth generate`.
- Validar la salida con `promtool check rules`.
- Comparar la salida con la versión a mano y argumentar cuál mantener.

## 4. Prerrequisitos
- Haber completado `obs-14-01`.
- **Software:** Docker ≥ 20.10. Imágenes: `ghcr.io/slok/sloth:v0.11.0`, `prom/prometheus:v2.54.1`.
- **Costo:** 0 (todo local).
- Sin cuentas cloud ni secrets.

## 5. Instrucciones
Esta actividad es **independent**: no hay solución guiada en el README. Pistas:

1. Completa `starter/slo.yaml` siguiendo el formato Sloth v1 (`version: prometheus/v1`, `service`, `slos: [{name, objective, sli: {events: {error_query, total_query}}, alerting}]`). Mira `../../examples/03-sloth-generate/slo.yaml` como referencia.
2. Genera las reglas:
   ```bash
   mkdir -p /tmp/obs-14-02
   docker run --rm -v "$(pwd)/starter:/w" -w /w ghcr.io/slok/sloth:v0.11.0 \
     generate -i slo.yaml -o /tmp/obs-14-02/generated-rules.yaml
   ```
3. Valida la salida:
   ```bash
   docker run --rm --entrypoint promtool -v /tmp/obs-14-02:/w -w /w \
     prom/prometheus:v2.54.1 check rules generated-rules.yaml
   ```
4. Compara con `../01-define-capstone-slos/solution/rules.yaml`:
   - ¿Cuántas recording rules genera Sloth vs las 5 a mano? ¿Por qué?
   - ¿Qué labels añade Sloth (`sloth_id`, `sloth_service`, `sloth_slo`)? ¿Para qué sirven en Alertmanager?
   - ¿La alerta `page` tiene la misma condición `burn_rate >= 14.4`?

5. Deja tu análisis escrito en `starter/comparison.md` (3-5 bullets).

## 6. Resultado esperado
- `starter/slo.yaml` válido para Sloth (SIN los defaults vacíos del placeholder).
- `generated-rules.yaml` en `/tmp/obs-14-02/` validado por `promtool`.
- `starter/comparison.md` con tu análisis.

## 7. Criterios de aceptación
- `bash tests/validate.sh` termina con `OK` (o `SKIP` si Docker no está disponible).
- La spec de SLO tiene objetivo numérico, SLI de eventos y bloques `page_alert`/`ticket_alert`.
- El análisis identifica al menos una ventaja y una desventaja de la generación.

## 8. Validación
```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Qué pasa si cambias `objective: 99.9` a `99.95`? ¿Hay que tocar las alertas?
- ¿Dónde vive la "fuente de verdad" en tu repo: en `slo.yaml` o en `generated-rules.yaml`? ¿Qué commiteas?
- ¿Cómo integrarías `sloth generate` en CI para que un PR al `slo.yaml` regenere automáticamente las reglas?
- ¿Qué le falta a Sloth comparado con OpenSLO? ¿Cuándo migrar?

## 10. Extensiones
- Añade un segundo SLO (latency) en el mismo `slo.yaml`.
- Explora `sloth generate --default-slo-period 28d`.
- Convierte el output a un `PrometheusRule` CRD (`kind: PrometheusRule`) para Prometheus Operator.

## 11. Limpieza
```bash
rm -rf /tmp/obs-14-02
docker image rm ghcr.io/slok/sloth:v0.11.0 || true
docker image rm prom/prometheus:v2.54.1 || true
```
