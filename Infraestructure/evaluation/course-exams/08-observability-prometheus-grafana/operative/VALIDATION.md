# Guía de corrección — ejercicio operativo

> Instructor-only. No compartir con el candidato antes de corregir.

## Resumen de puntaje

| Tarea | Peso | Validación automática | Validación manual |
|-------|------|-----------------------|-------------------|
| OP-task-1 recording rules | 10 | `promtool check rules` sale 0 + presencia de las 5 reglas | convención de naming correcta, no reusa queries O(N) |
| OP-task-2 relabel + cardinalidad | 8 | `promtool check config` sale 0 + presencia de drop del label `path` con regex UUID | drop está en `metric_relabel_configs` (post-scrape), no en `relabel_configs` |
| OP-task-3 MWMBR | 12 | tests pasan | fórmulas 14.4 / 6; labels severity; annotations completos |
| OP-task-4 tests | 5 | `promtool test rules` sale 0 | casos cubren happy-path, dispara, no dispara |
| OP-task-5 Alertmanager + dashboard | 5 | `amtool check-config` + JSON válido | inhibition presente; grouping defendido; `$service` templating |

Total operativa: 40 puntos.

## Red flags (rebajan 1 nivel; dos o más → no aprobado)

- Secreto real en cualquiera de los YAML.
- Label `user_id`, `request_id`, `email`, `trace_id`, URL completa con query string, path con UUID sin recortar.
- Alerta `rate(` sobre gauge, o `histogram_quantile` sobre summary.
- Alerta de SLO con una sola ventana.
- `honor_labels: true` sin justificación.
- Pushgateway como mecanismo general.
- ServiceMonitor sin label `release=kps`.
- `tls_config.insecure_skip_verify: true` sin justificación.

## Errores comunes esperados

1. Pone el drop del label `path` en `relabel_configs` → **no funciona**: no tiene `__name__` todavía. Deducir 2 puntos y pedir corrección verbal; si lo pone en el sitio correcto en revisión live, otorgar hasta 2/3.
2. Define `SLOBurnFast` sólo con ventana corta (5m) → red flag C10. 0 / 3 en el criterio y pedir rediseño.
3. Usa `avg` en lugar de `sum / sum` para error ratio → silencia servicios de bajo tráfico (ver pregunta de seguimiento Q8).
4. `group_wait: 0s` → alertas no se agrupan; no es ilegal pero muestra desconocimiento.
5. Dashboard que no usa recording rules sino queries crudas (`sum(rate(...` directo) → 1 / 3: funciona pero no amortiza.
6. ServiceMonitor en el ADR mencionado sin label `release`.

## Señales de "copió sin entender"

- Fórmulas 14.4 y 6 citadas sin justificar (ver Q8).
- `for: 0s` o `for: 10m` sin relación con la ventana.
- `job:` prefix en una métrica que agrega *entre* jobs.
- Un receiver `email: it@acme.com` con contraseña SMTP hardcodeada.

## Preguntas de seguimiento operativas (live)

- "Rompé mi dashboard: cambia la cardinalidad del label `service` a 10 000 valores y mídelo con `prometheus_tsdb_head_series`." 
- "Hacé fallar `promtool test rules` con un cambio de una sola línea en el `expr`." 
- "Si quito la `and` en `SLOBurnFast`, ¿qué pierdo?" 
- "Agregá un `low_traffic` guard a tu MWMBR para no alertar con <10 req/s."
