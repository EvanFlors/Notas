# REFERENCE — plat-03-02-poc-matrix-for-your-org

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte. Si tu contexto justifica otros pesos y escenarios, la matriz cambia; lo que **no** cambia es la **disciplina**.

---

# POC-MATRIX — Acme Fintech

## Sección A — Contexto organizacional

- Developers totales: ~250.
- Equipos / servicios: 18 equipos / 40 microservicios.
- Platform team: 3 FTE (2 K8s/Go, 1 K8s/Python+algo TS). Bandwidth real: ~2.5 FTE para IDP.
- Stack: 70% Go, 25% Python, 5% TS/React. EKS multi-region.
- Compliance: SaaS permitido para herramientas internas.
- Presupuesto: capex ingeniería ya cubierto; opex software hasta $150k/año.
- Horizonte: 18 meses, con revisión formal al llegar a 400 devs.

## Sección B — Finalistas y descartes

### Finalistas

- **Port** — SaaS que calza con el bandwidth real del equipo y el horizonte 18 meses.
- **Backstage self-hosted** — para contrastar: queremos saber si el ahorro de licencia justifica el costo de operación con nuestro equipo actual.

### Descartes razonados

- **OpsLevel** — su valor principal (scorecards) resuelve un problema secundario; nuestro primer dolor es inventario + onboarding, no madurez promedio.
- **Cortex** — mismo diagnóstico que OpsLevel + traslape de propuesta.
- **Humanitec** — resuelve "muchos entornos deriva" que **no** es nuestro problema (3 entornos estándar); podría convivir en el futuro con el ganador como orchestrator.
- **CNOE** — reference stack valiosa, pero nuestro equipo solo tiene 1 ingeniero cómodo con Crossplane y 0 con Keycloak productivo. CNOE ordena pero no reduce la carga de 5 componentes.

## Sección C — Matriz de criterios ponderados

| # | Criterio                             | Dimensión         | Peso | Métrica medible                                              |
|---|--------------------------------------|-------------------|------|--------------------------------------------------------------|
| 1 | Time-to-first-template productivo    | DX                |  15  | horas desde setup hasta primer template usado por 1 team     |
| 2 | Costo total 12 meses (TCO)           | Costo             |  15  | USD (licencia + horas internas de operación)                 |
| 3 | Operabilidad (upgrades + day-2)      | Operabilidad      |  12  | horas/mes dedicadas a upgrades, parches, incidentes          |
| 4 | Extensibilidad (plugin K8s custom)   | Extensibilidad    |  10  | ¿viable en < 2 semanas sin TS fuerte? sí/no + horas          |
| 5 | Scorecards nativos                   | DX                |  10  | nº checks posibles sin dev frontend                          |
| 6 | Catálogo: ingest + modelado          | DX                |  10  | tiempo para catalogar 40 servicios + annotations correctas   |
| 7 | Adopción interna (NPS piloto)        | Adopción          |  15  | NPS 1–10 de 5 developers piloto post-onboarding              |
| 8 | Lock-in / reversibilidad             | Lock-in           |  13  | ¿export del catálogo + blueprints a Git? completitud 0–100%  |
|   | **TOTAL**                            |                   | **100** |                                                           |

### Justificación de pesos

- **Costo (15)**: budget estricto; una herramienta que cuadre con nuestros 2.5 FTE efectivos gana.
- **Adopción interna (15)**: hemos tenido 2 portales previos fallidos por rechazo; cualquier decisión que no superpase NPS 6 es un fracaso predecible.
- **Time-to-first-template (15)**: necesitamos entregable visible en 90 días para defender presupuesto.
- **Lock-in (13)**: horizonte 18 meses obliga a mantener reversibilidad.
- **Operabilidad (12)**: con 2.5 FTE no podemos sostener day-2 pesado.
- **Extensibilidad (10)**: importante pero no urgente — en 18 meses tendremos quizá 1 caso real.
- **Scorecards (10)** y **Catálogo (10)**: fundamentos, pero ambos finalistas los resuelven razonablemente.
- **Compliance** no entra como criterio porque SaaS está permitido en nuestro contexto.
- **Hiring** no entra como criterio directo (se refleja indirecto en "operabilidad" y "extensibilidad").

## Sección D — Escenarios de uso

### Escenario 1 — Onboarding de un microservicio Go nuevo

- Pasos: scaffold (nombre, equipo, dominio) → repo creado → CI GHA green → Argo CD app sincronizada → aparece en catalog con owner → docs TechDocs renderizadas → scorecard inicial calculado.
- Medimos: tiempo total, pasos manuales fuera del portal, UX del developer.
- Criterio de éxito: < 30 min end-to-end; 0 pasos manuales fuera del portal; developer "entendió sin ayuda".

### Escenario 2 — Scorecard de madurez para 10 servicios

- Pasos: definir 5 checks (owner, SLO definido, runbook linked, imagen firmada, deploy frequency > weekly) → aplicar a 10 servicios → dashboard agregado por dominio.
- Medimos: tiempo de setup del scorecard, legibilidad del reporte por un lead ajeno al platform team.
- Criterio de éxito: setup total < 3 h; reporte interpretable por un lead en < 1 min.

### Escenario 3 — Cambio de ownership y auditoría de impacto

- Pasos: cambiar owner de 1 servicio → ver impacto en catálogo (quién depende de él, qué APIs expone) → notificar al nuevo equipo → auditoría de histórico.
- Medimos: trazabilidad del cambio, consistencia cross-vistas, notificación.
- Criterio de éxito: cambio reflejado en < 1 h; impacto visible sin query manual; auditoría conserva owner anterior.

### Escenario 4 — (opcional) Deprecación de un template

- Pasos: marcar template v1 como deprecated → publicar v2 → usuarios que arranquen reciben warning → métrica de uso del template viejo decrece.
- Medimos: visibilidad del warning, trazabilidad de uso.
- Criterio de éxito: warning visible en UI; uso de v1 decae a 0 en 30 días.

## Sección E — Plan 2–4 semanas y go/no-go

### Cronograma

- **Día 0**: PE lead setupea Port trial y create-app Backstage en EKS staging. Checkpoint arranque con todo el equipo.
- **Semana 1**: catálogo de 20 servicios en ambas; ejecutar Escenario 1 con 2 developers piloto. Checkpoint fin de semana.
- **Semana 2**: Escenario 2 (scorecards); recolectar observaciones de 2 engineering leads.
- **Semana 3**: Escenario 3 (ownership) + entrevistas 1:1 con 5 developers piloto (plantilla de 10 preguntas estándar en ambos lados).
- **Semana 4**: cálculo de la matriz, reporte de 2 páginas, decisión go/no-go presentada al CTO.

### Responsables

- Operadores: PE engineer #1 (Backstage), PE engineer #2 (Port).
- Observadores: 2 engineering leads de dominios distintos.
- Piloto: 5 developers (2 Go backend, 2 Python backend, 1 frontend).
- Decision maker: PE lead + CTO.

### Decision framework

- Suma ponderada por criterio, escala 0–10 por herramienta.
- **Ganador**: puntuación más alta.
- **Tie-breaker** (diferencia < 5 puntos sobre 100): **Adopción interna (NPS piloto)**, por mayor peso implícito en el contexto.
- **Umbral mínimo**: si ambos < 60/100 → **plan B**: no adoptar portal todavía, documentar golden paths en Markdown en repo central durante 6 meses, revisar.

### Riesgos del PoC

- **Soporte VIP del vendor** inflando la experiencia durante trial → mitigación: validar en el contrato el SLA de soporte **productivo**, no de trial.
- **Favoritismo del operador**: quien configuró Port lo prefiere por conocimiento → mitigación: separar "operadores" de "evaluadores"; los evaluadores son los developers piloto, no el platform team.
- **Escenarios diseñados por el vendor**: usar **nuestros** escenarios (sección D), no las demos oficiales.
- **Confusión capex/opex** → mitigación: TCO en una tabla única con mismas asunciones (horas internas, salario promedio, horizonte 12 meses).

## Sección F — Costo total estimado del PoC

- Horas de ingeniería interna: ~160 h (4 semanas × 2 ing × 20 h/semana) × $100/h = **$16,000**.
- Licencias trial: Port trial gratis; Backstage OSS gratis → **$0**.
- Overhead developers piloto: 5 devs × 8 h = 40 h × $100/h = **$4,000**.
- **Total estimado del PoC: ~$20,000** (ingeniería absorbida; costo real cash: $0).

---

## Plantilla breve de reporte final del PoC (sección opcional)

```
1. Resumen ejecutivo (3 bullets)
2. Resultado matriz (tabla + ganador)
3. Highlights por escenario (1 bullet por herramienta, por escenario)
4. Riesgos no mitigados
5. Decisión y follow-ups
```

Audiencia: CTO + engineering leads. Longitud máxima: 2 páginas.
