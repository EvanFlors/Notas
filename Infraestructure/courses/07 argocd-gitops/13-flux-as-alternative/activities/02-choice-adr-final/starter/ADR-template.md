# ADR-013: {decisión en una línea}

> Plantilla. Reemplaza TODO lo que esté entre {llaves} y borra esta nota.

## Status
Proposed | Accepted | Deprecated | Superseded by [ADR-NNN]

## Context
{Describe la organización: tamaño, equipos, workloads, restricciones regulatorias, cultura.
Describe lo que ya existe (si hay Argo CD operativo, Flux operativo, nada).
Describe el síntoma que fuerza decidir ahora.}

## Decision Drivers
Criterios con pesos (suman 100%):
- {Driver 1} — peso {X}%
- {Driver 2} — peso {Y}%
- …

## Considered Options
1. **Argo CD**
2. **Flux v2**
3. (opcional) **Ambos simultáneamente** (sharding por dominio)
4. (opcional) **Ninguno** (seguir con pipelines push)

## Decision Outcome
Opción elegida: **{opción}**.
Puntaje por opción (0–10 por criterio × peso):
{tabla o texto corto con el cálculo}

Justificación narrativa:
{2–4 párrafos conectando criterios con evidencia observada en el curso.}

## Consequences
**Positivas:**
- …

**Negativas / riesgos:**
- …

## Exit Plan
Si en 12 meses esta decisión no funciona:
- Trigger: {métrica o síntoma que gatilla reevaluación}
- Pasos para migrar en reverso: {esquema del plan}
- Costo estimado: {horas-persona, downtime}

## Autor y fecha
{Nombre} — {YYYY-MM-DD}
