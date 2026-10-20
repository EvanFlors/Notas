# POC-MATRIX — IDP evaluation para <nombre-organizacion>

## Sección A — Contexto organizacional

- Developers totales: <N>
- Equipos / servicios estimados: <N / N>
- Platform team: <FTE, skills, bandwidth real>
- Stack técnico predominante: <lenguajes, runtime, cloud>
- Compliance: <SaaS permitido / self-hosted obligatorio>
- Presupuesto: <capex ingeniería / opex per-dev>
- Horizonte de decisión: <12 / 18 / 24 meses>

## Sección B — Finalistas y descartes

### Finalistas elegidos

- **<Herramienta 1>** — por qué queda.
- **<Herramienta 2>** — por qué queda.

### Descartes razonados (al menos 4)

- **<Herramienta descartada 1>** — razón específica.
- **<Herramienta descartada 2>** — razón específica.
- **<Herramienta descartada 3>** — razón específica.
- **<Herramienta descartada 4>** — razón específica.

## Sección C — Matriz de criterios ponderados

Pesos suman 100. Cada criterio tiene una métrica medible.

| # | Criterio                           | Dimensión         | Peso | Métrica / señal medible                       |
|---|------------------------------------|-------------------|------|-----------------------------------------------|
| 1 | Time-to-first-template             | DX                |  15  | horas desde setup hasta template productivo   |
| 2 | Extensibilidad (plugin custom)     | Extensibilidad    |  15  | ¿posible plugin K8s custom? sí/no + horas     |
| 3 | Costo a 12 meses                   | Costo             |  15  | USD estimados (opex + capex ingeniería)       |
| 4 | Operabilidad (upgrades, backups)   | Operabilidad      |  10  | horas/mes dedicadas a day-2                   |
| 5 | Lock-in / reversibilidad           | Lock-in           |  10  | ¿export catalog? ¿rehacer plugins?            |
| 6 | Scorecards nativos                 | DX                |  10  | nº checks posibles sin dev                    |
| 7 | Catálogo (modelado + ingest)       | DX                |  10  | tiempo para catalogar 20 servicios            |
| 8 | Adopción interna (NPS piloto)      | Adopción          |  15  | NPS 1–10 de 5 developers piloto               |
|   | **TOTAL**                          |                   | **100** |                                            |

### Justificación de pesos

- "Costo a 12 meses" vale 15 porque <...>.
- "Adopción interna" vale 15 porque <...>.
- "Compliance" no entra porque <...>.
- ...

## Sección D — Escenarios de uso

### Escenario 1 — Onboarding de un servicio nuevo

- Pasos: scaffold → repo creado → CI green → aparece en catalog → docs renderizadas.
- Medimos: tiempo total, pasos manuales, UX del developer piloto.
- Criterio de éxito: < 30 min, 0 pasos manuales fuera del portal.

### Escenario 2 — Scorecard de madurez para 5 servicios

- Pasos: definir 3 checks (owner, SLO, runbook) → evaluar 5 servicios → vista agregada.
- Medimos: tiempo setup, legibilidad del reporte.
- Criterio de éxito: setup < 2 h, reporte interpretable por un lead en 1 min.

### Escenario 3 — Deprecación / cambio de owner

- Pasos: cambiar owner de un servicio → auditar impacto → notificar al nuevo equipo.
- Medimos: trazabilidad, notificaciones, consistencia.
- Criterio de éxito: cambio reflejado en < 1 h sin intervención manual.

## Sección E — Plan 2–4 semanas y go/no-go

### Cronograma

- **Día 0**: setup trial Port + create-app Backstage; checkpoint arranque.
- **Semana 1**: catalogar 20 servicios en ambas; escenario 1 (onboarding).
- **Semana 2**: implementar scorecard + escenario 2.
- **Semana 3**: escenario 3 + entrevistas con 5 developers piloto.
- **Semana 4**: cálculo matriz, reporte, decisión go/no-go.

### Responsables

- Operadores: <nombres del platform team>.
- Observadores: engineering leads.
- Piloto: 5 developers de 3 equipos distintos.

### Decision framework

- Suma ponderada: la herramienta con mayor puntuación gana.
- Si diferencia < 5 puntos → tie-breaker: **adopción interna** (NPS piloto).
- Si ambos < 60/100 → **plan B**: no adoptar portal todavía, revisar en 6 meses.

### Riesgos del PoC

- **Soporte VIP del vendor durante PoC** que luego cae a estándar → mitigación: validar SLA del plan real.
- **Favoritismo del equipo plataforma** → mitigación: separar "operadores" de "evaluadores".
- **El escenario del vendor** no refleja uso real → mitigación: usar **nuestros** escenarios, no los suyos.

## Sección F — (opcional) Costo total estimado del PoC

- Horas de ingeniería interna: <N> h × <USD/h> = <USD>
- Licencias trial / costos: <USD>
- Total estimado: <USD>
