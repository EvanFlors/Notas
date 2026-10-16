# obs-15-01 — Platform Observability Contract (ADR) — independiente

## 1. Identificación
- **ID:** `obs-15-01-platform-contract-adr`
- **Tecnología:** prometheus-grafana
- **Módulo:** `15-platform-dashboards-and-alerts-as-code-governance`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** architecture (independiente)

## 2. Contexto
Te asignan "arreglar la observabilidad" de una org con 30 servicios, 7 teams, Prometheus Operator en K8s, Grafana con 180 dashboards (nadie sabe cuántos son los "buenos"), 400 reglas de alerta sin ownership claro y una factura mensual de observabilidad que creció 3× en seis meses sin explicación.

El entregable que te piden es **un ADR**: *Platform Observability Contract*. Un documento corto que defina las reglas del juego para que, de aquí en adelante, dashboards, alertas, SLOs y costos sean gobernables.

Es un ejercicio **independiente**: no hay guía paso-a-paso. Lee la lección, mira los ejemplos, decide y defiende tus decisiones.

## 3. Objetivos
- Escribir un ADR en forma estándar (Status, Context, Decision, Consequences, Alternatives, Review cadence).
- Definir labels obligatorios y justificar la elección.
- Fijar una política de tiers con retention y presupuesto.
- Fijar reglas para dashboards (as code, templates) y alertas (as code, tests, routing, runbook obligatorio).
- Documentar al menos 2 alternativas descartadas con el porqué.

## 4. Prerrequisitos
- Haber leído `theory/lesson.md` completo.
- Haber corrido los 3 ejemplos.
- Herramientas: un editor de texto, `bash`, `grep`. No hay dependencias ni costos.

## 5. Instrucciones

```bash
# 1) Scratch dir
mkdir -p /tmp/obs15-01
cp -r starter/* /tmp/obs15-01/

# 2) Edita /tmp/obs15-01/ADR-OBS-001.md con tu contrato.
#    La estructura es obligatoria; el contenido es tuyo.
```

El ADR **debe** tener exactamente estas secciones (headers de nivel 2, en orden):

```markdown
## Status
## Context
## Decision
## Consequences
## Alternatives considered
## Review cadence
```

Dentro de `## Decision` debes cubrir, cada uno como *sub-sección* o bullet claramente marcado:

- **Labels obligatorios** (mínimo 4 labels, cada uno con justificación).
- **Naming conventions** (métricas, recording rules, alertas, dashboards, folders Grafana).
- **Tiers y retention policy** (tabla con al menos 3 tiers).
- **Dashboards as code** (herramienta elegida, ubicación en repo, CI).
- **Alerts as code** (requisito de tests `promtool`, labels obligatorios en alertas, runbook obligatorio).
- **SLO contract per service** (qué servicios lo necesitan, formato).
- **Ownership y routing** (quién recibe qué, cómo).
- **Presupuesto** (una cifra mensual por tier o por servicio, con justificación).

Dentro de `## Alternatives considered`: al menos 2 alternativas rechazadas (p. ej. "Datadog SaaS", "mantener dashboards manuales", "sin tiers") con 1-2 frases de porqué.

El validador comprueba **estructura y palabras clave**, no la calidad conceptual (eso lo revisa un humano o tú mismo mañana).

## 6. Resultado esperado
- `/tmp/obs15-01/ADR-OBS-001.md` existe y pasa `tests/validate.sh`.
- Longitud razonable (>= 50 líneas no vacías).
- Cada decisión está justificada, no es sólo un bullet point.

## 7. Criterios de aceptación
- Las 6 secciones existen con el header exacto.
- Todas las sub-decisiones listadas en §5 aparecen en `## Decision`.
- Mencionas al menos 4 labels obligatorios.
- Mencionas al menos 3 tiers.
- Mencionas `grafonnet` o `grizzly` o `terraform` como mecanismo as-code para dashboards.
- Mencionas `promtool` como test runner de alertas.
- Mencionas `runbook` como requisito en alertas.
- Mencionas una cifra `$` como presupuesto.
- Mencionas al menos 2 alternativas descartadas.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- Si el equipo A rechaza aceptar `team` como label obligatorio porque "ya está en el namespace de K8s", ¿qué le respondes? ¿qué pasa si su servicio escala a multi-cluster?
- ¿Por qué tener un tier `bronze` sin LTS puede ser *más* útil que no tener `bronze`?
- ¿Qué pasa si el presupuesto por servicio se excede? ¿Alerta? ¿Bloquear deploy? ¿Reporte?
- ¿Dónde encaja Backstage/IDP en este contrato (opcional, obligatorio, no mencionado)?

## 10. Extensiones
- Añade una sección "Migration plan" con 3 fases para llevar la org actual (180 dashboards, 400 alertas sin owner) al estado objetivo.
- Diseña una métrica de "madurez de observabilidad" por team (score 0-100) y cómo publicarla.

## 11. Limpieza

```bash
rm -rf /tmp/obs15-01
```
