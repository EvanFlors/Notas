# Actividad 01 — Definir recording rules RED del capstone

## 1. Identificación

- **ID:** `obs-10-01-define-recording-rules-for-capstone`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `10-promql-advanced-recording-rules-cardinality`
- **Dificultad:** advanced
- **Duración estimada:** 45–75 min
- **Tipo:** guided-lab

## 2. Contexto

El capstone del programa expone métricas RED (`http_requests_total`, `http_request_duration_seconds_bucket`) desde una app FastAPI. Hoy, los dashboards del equipo repiten expresiones largas en cada panel y las alertas repiten las mismas en cada regla. Vas a definir 3 recording rules "ingredientes" que absorben el coste y simplifican todo lo que las consume.

Esto es también el **prerrequisito práctico** del módulo `obs-14` (SLOs): las burn-rate alerts solo son viables si descansan sobre recording rules.

## 3. Objetivos

- Escribir **3 recording rules** siguiendo la convención `level:metric:operations`:
  1. `job:http_requests:rate5m` — rate de requests por job (ventana 5 min).
  2. `job:http_errors:ratio5m` — ratio de errores 5xx por job.
  3. `job:http_request_duration:p99_5m` — percentil 99 de latencia por job (desde classic histogram).
- Validar con `promtool check rules` que la sintaxis es correcta.
- Validar con `promtool test rules` que la semántica es correcta sobre series de prueba.
- Documentar por escrito **qué dashboard/alerta** aguas abajo se simplifica con cada regla.

## 4. Prerrequisitos

- `promtool` instalado (viene con la distribución Prometheus). Si no, la validación degrada con `SKIP`.
- Conceptos: `rate`, `sum by`, `histogram_quantile` del módulo `obs-04`.
- Haber leído `theory/lesson.md` secciones 3, 4 y 9.

**Costos**: ninguno (todo local, sin cloud).

## 5. Instrucciones

### 5.1 Explorar el starter

```bash
cd courses/prometheus-grafana/10-promql-advanced-recording-rules-cardinality/activities/01-define-recording-rules-for-capstone
ls starter/
cat starter/rules.yml
cat starter/rule_test.yml
```

El `starter/rules.yml` trae el esqueleto con 3 reglas marcadas con `# TODO`. El `starter/rule_test.yml` ya tiene las series sintéticas de entrada y las assertions esperadas — **no debes tocarlo**.

### 5.2 Completar `rules.yml`

Edita `starter/rules.yml` y rellena cada `# TODO` con la expresión PromQL correcta. Pistas:

- **Regla 1** — `job:http_requests:rate5m`: `sum by (job) (rate(http_requests_total[5m]))`.
- **Regla 2** — `job:http_errors:ratio5m`: ratio de 5xx sobre el total, agrupado por `job`.
- **Regla 3** — `job:http_request_duration:p99_5m`: `histogram_quantile(0.99, sum by (job, le) (rate(http_request_duration_seconds_bucket[5m])))`.

Fíjate en qué hace cada `by (...)` — determina la cardinalidad resultante.

### 5.3 Validar sintaxis

```bash
promtool check rules starter/rules.yml
```

Debe decir `SUCCESS: 3 rules found`.

### 5.4 Validar semántica

```bash
promtool test rules starter/rule_test.yml
```

Debe decir `SUCCESS`. Si falla, lee el diff que imprime: casi siempre indica que una `by (...)` está incompleta o que falta un selector.

### 5.5 Validar con el harness

```bash
bash tests/validate.sh
```

Debe terminar con `OK`.

### 5.6 Documentar aguas abajo

Añade al final de tu `starter/rules.yml` un comentario por regla indicando:

- Qué panel de Grafana la consumirá.
- Qué alerta la consumirá (nombre y expresión simplificada).

Ejemplo:

```yaml
# job:http_errors:ratio5m
#   consume: dashboard "capstone-red" panel "Error ratio by job"
#   consume: alert "HighErrorRate" (expr: job:http_errors:ratio5m > 0.05 for 5m)
```

## 6. Resultado esperado

- `starter/rules.yml` tiene las 3 reglas completas, nombradas con la convención.
- `promtool check rules` pasa.
- `promtool test rules` pasa.
- Hay comentarios de "consume aguas abajo" por cada regla.

## 7. Criterios de aceptación

- [ ] Funcional: `promtool test rules` emite `SUCCESS` sobre las series sintéticas provistas.
- [ ] Naming: los 3 record names siguen la convención `level:metric:operations`.
- [ ] Cardinalidad: cada `by (...)` está justificado — no se cuela una dimensión innecesaria.
- [ ] Reproducible: cualquiera clona, corre `bash tests/validate.sh` y obtiene `OK`.
- [ ] Mantenible: cada regla tiene su comentario de "consume aguas abajo".

## 8. Validación

```bash
bash tests/validate.sh
```

El harness verifica: `rules.yml` existe, trae exactamente los 3 record names esperados, `promtool check rules` pasa, y `promtool test rules` pasa. Si `promtool` no está instalado, degrada con `SKIP` en esos pasos pero sigue verificando estructura.

## 9. Preguntas de reflexión

1. ¿Por qué `job:http_errors:ratio5m` ahorra más coste que `job:http_requests:rate5m`? ¿Es siempre así?
2. Si añadieras una 4ª regla `job:service:http_errors:ratio5m by (job, service, path)`, ¿qué pasa con el nº de series? ¿Lo recomendarías?
3. ¿Por qué el p99 se calcula con `sum by (job, le)` y no con `sum by (job)`? ¿Qué pasaría si olvidas `le`?
4. Diseña una alerta que consuma `job:http_request_duration:p99_5m` para "latencia alta sostenida". ¿Qué `for:` elegirías y por qué?
5. ¿Qué pasa con tus recording rules si Prometheus está sin datos durante 10 min (restart)? ¿Las series tienen gap, se reconstruyen hacia atrás, se pierden?

## 10. Extensiones

- **E1** — Añade `job:http_requests:rate1h` para dashboards de ventanas largas; justifica si vale la pena.
- **E2** — Agrupa las reglas en **dos grupos** separados (`red-rate`, `red-latency`) y explica por qué.
- **E3** — Añade un `rule_test.yml` adicional que simule un **gap** de datos y verifica cómo se comporta `rate()`.
- **E4** — Reescribe la regla de ratio usando `avg_over_time(…[5m])` sobre una ratio ya calculada por intervalo. Compara con la implementación default y discute qué mide realmente cada una.

## 11. Limpieza

```bash
# Nada persistente que limpiar; promtool no deja estado.
rm -f /tmp/promtool-* 2>/dev/null || true
```
