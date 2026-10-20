# Actividad 02 — Reescribir alertas: señal vs ruido

## 1. Identificación

- **ID:** `k8s-15-02-tune-alerts-signal-vs-noise`
- **Tecnología:** `kubernetes`
- **Módulo:** `15-observability-in-k8s`
- **Dificultad:** advanced
- **Duración estimada:** 60–120 min
- **Tipo:** independent

## 2. Contexto

Recibís un `PrometheusRule` con **10 alertas** heredadas de un equipo que ya no está. El on-call confirma que tres de ellas se disparan sin parar y nadie les hace caso. Tu trabajo es:

1. **Identificar** las 3 ruidosas.
2. **Reescribirlas** usando criterios reales (SLO + multi-window burn-rate) o **eliminarlas** si no corresponden a nada accionable.
3. **Dejar intactas** las 7 sanas.
4. **Añadir** `annotations.summary`, `annotations.description` y `annotations.runbook_url` a toda alerta sin ellas.

No es un ejercicio de infraestructura — es de criterio. El cluster puede estar o no.

## 3. Objetivos

- Leer `starter/alerts.yaml` y marcar cuáles tres alertas son ruidosas y por qué.
- Editar `starter/alerts.yaml` en su lugar (sobrescribir) o escribirlo en `starter/alerts.fixed.yaml` — el validador acepta ambos nombres.
- El archivo final debe:
  - Ser YAML válido.
  - Mantener la estructura `PrometheusRule` (`apiVersion`, `kind`, `metadata`, `spec.groups[].rules[]`).
  - No contener la alerta literal `HighCpuUsage` con `rate(container_cpu_usage_seconds_total[1m]) > 0.1 for 1m` (ruidosa canónica).
  - No contener la alerta literal `MemoryUsage` con `container_memory_usage_bytes > 1` (comparación absurda).
  - No contener la alerta `PodPresent` con expresión que se disparará siempre que haya al menos un Pod.
  - Incluir al menos **una regla SLO**: una alerta con `_burn_rate_` o `budget` en el nombre, o con dos ventanas (`[5m]` y `[1h]`) en la expr.
  - Toda alerta debe tener los tres annotations.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md §9` (señal vs ruido, SLO + burn-rate).
- `bash` + `python3` con `pyyaml` para el validador. Si falta `pyyaml`, el validador degrada a checks por `grep`.

**Costos**: ninguno.

## 5. Instrucciones

**No** mires `solution/` antes de intentarlo. Al final podés comparar.

### 5.1 Leer el starter

```bash
cd courses/kubernetes/15-observability-in-k8s/activities/02-tune-alerts-signal-vs-noise
cat starter/alerts.yaml
```

Las 10 alertas están comentadas con `# TAG:` que indica si fueron pensadas sanas o ruidosas (en producción no tendrás ese pistón; está acá como andamio didáctico).

### 5.2 Elegir estrategia por alerta ruidosa

Para cada alerta `TAG: NOISY`, elegí uno de:

- **Eliminar** si no modeliza nada accionable (p. ej. `PodPresent`).
- **Reescribir como SLO burn-rate** si representa una métrica de salud real (p. ej. errores HTTP).
- **Añadir contexto** (`for:` más largo, umbral absoluto en lugar de relativo, agregación por labels de dueño) si la señal es útil pero el disparo es prematuro.

### 5.3 Modelo de referencia (patrón multi-window)

```yaml
- record: slo:availability_errors:ratio_rate5m
  expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
- record: slo:availability_errors:ratio_rate1h
  expr: sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h]))

- alert: SLOErrorBudgetBurnRateFast
  expr: slo:availability_errors:ratio_rate5m > (14.4 * 0.001)
    and slo:availability_errors:ratio_rate1h > (14.4 * 0.001)
  for: 2m
  labels: { severity: critical, team: platform }
  annotations:
    summary: "Error budget burning > 14.4x (fast)"
    description: "El servicio quema el budget 14.4x en 5m y 1h. 2% del presupuesto en 1h."
    runbook_url: "https://runbooks.example.com/slo-fast-burn"
```

### 5.4 Añadir annotations faltantes

Toda alerta sin `summary`, `description` o `runbook_url` debe recibir uno coherente. Para `runbook_url` basta un placeholder consistente, p. ej. `https://runbooks.example.com/<alertname>`.

### 5.5 Validar

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- `starter/alerts.yaml` (o `starter/alerts.fixed.yaml`) existe, es YAML válido.
- No contiene las 3 alertas ruidosas canónicas.
- Contiene al menos una regla `record` **y** una alerta con doble ventana o nombre que incluye `burn_rate` o `BurnRate`.
- Toda alerta tiene los tres annotations.

## 7. Criterios de aceptación

- [ ] **Criterio**: justificaciones escritas (en el YAML como `# comment` sobre cada decisión).
- [ ] **Correctitud**: el `PrometheusRule` sería aplicable (`kubectl apply --dry-run=client`) — el validador lo chequea estructuralmente.
- [ ] **Completitud**: las 7 alertas sanas se preservan.
- [ ] **Semántica**: la reescritura cumple el patrón multi-window **o** elimina la alerta explícitamente.
- [ ] **Operación**: cada alerta tiene runbook_url.

## 8. Validación

```bash
bash tests/validate.sh
```

Checks:
1. Existe `starter/alerts.yaml` o `starter/alerts.fixed.yaml`.
2. Es YAML válido (`python3 -c "import yaml; yaml.safe_load(open(...))"`), o fallback `grep` por estructura mínima.
3. `kind: PrometheusRule`.
4. No existen las 3 alertas prohibidas (nombre + expr).
5. Existe al menos una `record` rule y una alerta con `burn_rate` / `BurnRate` / dos ventanas (`[5m]` **y** `[1h]`).
6. Toda alerta tiene `summary`, `description`, `runbook_url`.

## 9. Preguntas de reflexión

1. ¿Por qué `rate(cpu) > 0.1 for 1m` es ruido? Analizá en términos de SLO, no de CPU.
2. ¿Qué diferencia hay entre una alerta `fast burn` y una `slow burn`? ¿Puede faltar una?
3. ¿Qué hacés con alertas que son "lindas de ver" pero jamás accionables? ¿Son alertas?
4. Si el servicio no tiene un SLO definido, ¿qué alertas podés escribir con criterio?
5. ¿Cómo testearías tus reglas en CI antes de aplicarlas al cluster? (pista: `promtool test rules`).

## 10. Extensiones

- **E1** — Añadir dos reglas más: multi-window para **latencia P99** (no solo error-rate).
- **E2** — Separar `record` rules en otro `group` para claridad.
- **E3** — Añadir `inhibit_rules` conceptualmente (en Alertmanager) para que `SLOFastBurn` silencie `SLOSlowBurn` del mismo servicio.
- **E4** — Escribir `promtool test rules` para probar la expresión `expr` con series sintéticas.

## 11. Limpieza

```bash
# Nada que limpiar en el cluster; esta actividad es solo de edición.
# Opcional: restaurar el starter original:
git checkout -- starter/alerts.yaml 2>/dev/null || true
rm -f starter/alerts.fixed.yaml
```
