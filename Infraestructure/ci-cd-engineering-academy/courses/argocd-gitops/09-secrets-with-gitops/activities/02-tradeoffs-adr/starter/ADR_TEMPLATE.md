# ADR-NNN — Estrategia de secretos en GitOps

- **Status:** proposed
- **Date:** YYYY-MM-DD
- **Deciders:** <nombres / equipos>
- **Revisit:** YYYY-MM-DD (un año)

## Context

Resumen en 1 párrafo del problema (secretos sin romper GitOps) y las 5 opciones.

## Decision table

| Criterio                | SOPS+KSOPS | Sealed Secrets | ESO | CSI Driver | Vault Injector |
|-------------------------|:----------:|:--------------:|:---:|:----------:|:--------------:|
| Blast radius            |            |                |     |            |                |
| Rotation UX             |            |                |     |            |                |
| Operator overhead       |            |                |     |            |                |
| Cost                    |            |                |     |            |                |
| Multi-cluster           |            |                |     |            |                |
| Compliance fit          |            |                |     |            |                |
| Migration cost          |            |                |     |            |                |

(Puntuación 1–5; 5 = mejor)

## Org 1 — Startup fintech en AWS

**Decision:** <estrategia>
**Why:** <≤150 palabras>
**Trade-offs:** <1+ contra>

## Org 2 — Agencia gubernamental air-gapped

**Decision:** <estrategia>
**Why:** <≤150 palabras>
**Trade-offs:** <1+ contra>

## Org 3 — Empresa industrial con Vault

**Decision:** <estrategia>
**Why:** <≤150 palabras>
**Trade-offs:** <1+ contra>

## Consequences (apuesta global del equipo)

<Qué ganas y qué pagas si el equipo adopta UNA estrategia como default.>

## Rotation plan

- Secretos de aplicación: cadencia + responsable.
- Claves maestras: cadencia + drill de rollback.
- Credenciales del operator al provider: cadencia + alertas.

## Links

- `theory/lesson.md`
- Documentación oficial de la estrategia elegida.
