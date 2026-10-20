# ADR-001: Selección de IDP para <nombre-organizacion-ficticia>

## Status

Proposed

## Context

<Describe la situación: ~250 developers, 3 ingenieros plataforma, 40 microservicios
Go/Python en EKS multi-tenant. Horizonte 24 meses. Presupuesto XYZ. Compliance
(SaaS vs self-hosted). Vendor X presionando con demo cerrada en 2 semanas.>

## Decision

Elegimos **<herramienta>** como IDP de referencia para los próximos 18–24 meses.

## Alternatives considered

- **<alternativa 1 — ej. Backstage self-hosted>** — <razón específica de descarte,
  no genérica. Ej.: "requiere 2–3 ingenieros TS dedicados, nuestros 3 FTE tienen
  perfil mixto K8s/Go y el 20% de TS no sostiene el day-2 de upgrades">.
- **<alternativa 2 — ej. Port>** — <razón específica>.
- **<alternativa 3 — ej. CNOE>** — <razón específica>.
- **<alternativa 4 — opcional (OpsLevel, Cortex, Humanitec)>** — <razón específica>.

## Consequences

### Positivas

- <consecuencia 1>
- <consecuencia 2>

### Negativas (aceptadas)

- <consecuencia 1 — ej. lock-in medio con vendor; mitigación: exportar blueprints
  mensualmente a Git>.
- <consecuencia 2 — ej. costo per-dev crecerá con la organización; mitigación:
  renegociar al llegar a 400 devs>.

## Follow-ups

- <acción 1 con dueño y horizonte — ej. "medir platform NPS en 90 días — PE lead">.
- <acción 2 — ej. "revisar ADR en 12 meses — PE lead + CTO">.
- <acción 3 — ej. "preparar backup plan de migración en 18 meses — todo el PE team">.

## Non-technical criteria weighed

- **Presupuesto (TCO)**: capex ingeniería interna vs opex per-developer.
- **Hiring**: disponibilidad de perfiles en el mercado laboral local.
- **Adopción interna**: aceptación por engineering leads y developers.
- **Vendor relationship / lock-in**: reversibilidad de la decisión en 18–24 meses.

## Notes

Este ADR responde a la presión comercial del vendor con criterios defendibles.
La decisión es revisable; los follow-ups definen cuándo.
