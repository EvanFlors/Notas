# obs-09-alertmanager-and-alert-design — Alertmanager y diseno de alertas

## Identificacion
- **ID:** `obs-09-alertmanager-and-alert-design`
- **Nivel:** intermedio
- **Duracion estimada:** 4 h
- **Prerrequisitos:** `obs-04-promql-fundamentals`

## Objetivo
Disparar y enrutar alertas **utiles**, no ruido. Al terminar, el estudiante escribe reglas de alerta Prometheus, las testea con `promtool test rules`, configura un route tree de Alertmanager con grouping/inhibition/silences y aplica criterios de diseno basados en **sintomas** (SLO/user-impact) para reducir alert fatigue.

## Temas y subtemas
1. **Reglas de alerta Prometheus**: `groups`, `rules`, `expr`, `for`, `labels`, `annotations`.
2. **Testing de reglas** con `promtool test rules` (series input, assertions `alertname`+`eval_time`).
3. **Alertmanager**: arquitectura (dedup, group, inhibit, silence, route, notify).
4. **Route tree**: receivers por severidad/equipo; `continue:`; matchers (`matchers:`, `match_re` legacy).
5. **Grouping**: `group_by`, `group_wait`, `group_interval`, `repeat_interval`.
6. **Inhibition**: `source_matchers`, `target_matchers`, `equal:`; silenciar B si A activa.
7. **Silences temporales**: amtool o UI, scope por matchers y tiempo.
8. **Receivers**: email, slack, webhook, pagerduty, msteams, opsgenie; secretos fuera del YAML.
9. **Alert fatigue** y antidotos: menos alertas, bien disenadas; cada alerta debe tener runbook y accion humana.
10. **Alertas sobre sintomas** (SLO/user-impact), no causas: patrones multi-window multi-burn-rate (introductorio; detalle en obs-14).
11. **Anti-patrones**: alertar sobre CPU alta sin impacto; alertas duplicadas por falta de inhibition; sin `for:` → flapping.
12. **Operacion**: reload (`SIGHUP`, `/-/reload`), validacion offline (`amtool check-config`), observabilidad del propio Alertmanager.

## Conceptos internos (fundamentos)
- `for: 5m` evita flaps: Prometheus mantiene la alerta en estado `pending` hasta que el `expr` sigue cierto durante ese tiempo.
- `group_wait` agrega alertas que llegan juntas (primera notificacion); `group_interval` es cadencia de updates al mismo grupo; `repeat_interval` es re-envio periodico si sigue firing.
- La inhibition reduce N alertas en cascada (ej. `NodeDown` → N `TargetDown` del nodo) a 1 notificable.
- Una alerta **sin runbook** o que no requiera accion humana es un bug.
- El routing es un **arbol**: la primera coincidencia gana a menos que `continue: true`.

## Competencias
- **Conceptual**: distinguir alerta de sintoma vs alerta de causa; diferenciar `group_wait` de `repeat_interval`.
- **Operativa**: escribir y testear reglas con `promtool`; construir un `alertmanager.yml` con route tree, inhibition y silences; validar con `amtool`.
- **Arquitectonica**: disenar politica de alertas para un servicio con SLO y multiples equipos receptores; criticar un set de alertas ruidosas y rediseniarlas.

## Ejemplos
- [`examples/01-first-alert-rule`](examples/01-first-alert-rule/) — primera regla + test `promtool`.
- [`examples/02-alertmanager-route-tree`](examples/02-alertmanager-route-tree/) — route tree con grouping por team/severity.
- [`examples/03-inhibition-example`](examples/03-inhibition-example/) — inhibition para suprimir cascada.

## Actividades
- [`activities/01-write-alerts-with-promtool-tests`](activities/01-write-alerts-with-promtool-tests/) — guided-lab (60 min).
- [`activities/02-reduce-alert-fatigue`](activities/02-reduce-alert-fatigue/) — independent (90 min); refactorizar 15 alertas ruidosas a 5 SLO-based.

## Entregables
- `alerts.yaml` (grupo con reglas RED y SLO) con tests `promtool test rules` que pasan.
- `alertmanager.yml` con route tree multi-equipo + inhibition + al menos un receiver webhook/slack.
- Documento `WHY.md` justificando por que cada alerta reducida merece paginar a un humano.

## Criterios de evaluacion
- **Funcionalidad**: `promtool check rules alerts.yaml` y `promtool test rules tests.yaml` sin errores; `amtool check-config alertmanager.yml` OK.
- **Diseno**: cada alerta tiene `for`, `severity`, `team`, `summary`, `description`, `runbook_url`.
- **Reduccion de ruido**: la actividad 02 justifica por que se eliminaron 10 alertas (duplicacion, causa en vez de sintoma, no actionable).

## Recursos
Ver [`resources/links.md`](resources/links.md).

## Teoria
Lectura completa: [`theory/lesson.md`](theory/lesson.md).
