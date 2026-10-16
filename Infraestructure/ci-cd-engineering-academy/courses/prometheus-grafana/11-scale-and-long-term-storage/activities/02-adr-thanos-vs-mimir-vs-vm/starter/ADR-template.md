# ADR-001 — Long-term metrics store para ACME Fintech

- **Estado:** PROPUESTO
- **Fecha:** YYYY-MM-DD
- **Autor:** <tu nombre>
- **Revisores:** <peer 1>, <peer 2>

---

## 1. Contexto

<!-- TODO: resume el estado actual de ACME Fintech en 5-10 líneas:
     clusters, series activas, equipos, presupuesto, compliance, cuellos actuales.
     Explica por qué este ADR se abre AHORA. -->

## 2. Fuerzas / drivers

<!-- TODO: lista explícita de drivers. Al menos:
     - Presupuesto (≤ 60 k USD/año).
     - Retención obligatoria (1 año para métricas billing_*).
     - Tamaño y skills del equipo (2 SRE + 1 platform; Helm sí, microservicios no).
     - Multi-tenant (3 equipos de producto).
     - Multi-región (us-east-1, eu-west-1, ap-south-1).
     - Crecimiento esperado (2x en 12 meses). -->

## 3. Opciones consideradas

- **A — Thanos** (sidecar + querier + store + compactor).
- **B — Grafana Mimir** (chart `grafana/mimir-distributed`).
- **C — VictoriaMetrics** (cluster: vminsert + vmstorage + vmselect; o vmsingle federado).
- **D — Cortex** — descartada up-front por: <!-- TODO: 1 línea de razón -->

## 4. Criterios de decisión ponderados

| # | Criterio | Peso (1-5) | Justificación del peso |
|---|----------|-----------|------------------------|
| 1 | <!-- TODO: p. ej. Coste operacional (microservicios, nº componentes) --> |  |  |
| 2 | <!-- TODO: p. ej. Coste de infra (storage + egress + compute) --> |  |  |
| 3 | <!-- TODO: p. ej. Soporte multi-tenant nativo --> |  |  |
| 4 | <!-- TODO: p. ej. PromQL fidelity --> |  |  |
| 5 | <!-- TODO: p. ej. Facilidad de migración desde Prometheus actual --> |  |  |
| 6 | <!-- TODO opcional: p. ej. Camino a SaaS/Grafana Cloud --> |  |  |

## 5. Comparación

Puntúa cada opción de 1 (malo) a 5 (excelente) contra cada criterio. Totales ponderados abajo.

| Criterio (peso) | Thanos | Mimir | VictoriaMetrics |
|-----------------|-------:|------:|----------------:|
| C1 (<!-- w -->) | <!-- --> | <!-- --> | <!-- --> |
| C2 (<!-- w -->) | <!-- --> | <!-- --> | <!-- --> |
| C3 (<!-- w -->) | <!-- --> | <!-- --> | <!-- --> |
| C4 (<!-- w -->) | <!-- --> | <!-- --> | <!-- --> |
| C5 (<!-- w -->) | <!-- --> | <!-- --> | <!-- --> |
| **Total ponderado** | <!-- --> | <!-- --> | <!-- --> |

## 6. Decisión

<!-- TODO: una frase. "Elegimos X porque Y." -->

## 7. Justificación

<!-- TODO: 3+ razones concretas ligadas a los drivers (sección 2).
     Nada de "es la mejor opción" sin aterrizar. -->

## 8. Consecuencias

**Positivas**:
- <!-- TODO -->
- <!-- TODO -->

**Negativas / trade-offs**:
- <!-- TODO -->
- <!-- TODO -->

**Abierto / revisitar en 12 meses**:
- <!-- TODO -->

## 9. Retention policy

| Resolución | Retención objetivo | Dónde vive | Comentario |
|------------|--------------------|------------|------------|
| raw (15s)  | <!-- TODO (días) --> | <!-- TODO --> | <!-- TODO --> |
| 5m downsampled | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| 1h downsampled | <!-- TODO (≥ 1 año para billing_*) --> | <!-- TODO --> | <!-- TODO --> |

## 10. Estimación de coste

Supuestos:
- Series activas totales (3 clusters): <!-- TODO -->
- Samples/s: <!-- TODO -->
- Bytes/sample comprimido: <!-- TODO (1-1.5) -->
- GB/día: <!-- TODO -->
- GB/año: <!-- TODO -->

| Partida | Estimación USD/año | Fórmula |
|---------|--------------------:|---------|
| Object storage | <!-- TODO --> | <!-- TODO --> |
| Egress cross-region | <!-- TODO --> | <!-- TODO --> |
| Compute (nodos / pods) | <!-- TODO --> | <!-- TODO --> |
| **Total** | <!-- TODO --> | — |

¿Entra en el presupuesto de 60 k USD/año? <!-- TODO: sí/no y qué recortar si no. -->

## 11. Rollout plan

| Fase | Alcance | Duración | Criterio de success | Rollback |
|------|---------|---------|---------------------|---------|
| 1 — PoC | <!-- 1 cluster, non-prod --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| 2 — Prod 1 región | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| 3 — Multi-región | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |
| 4 — Decomm Prometheus LTS actual | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> |

## 12. Riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------:|--------:|-----------|
| <!-- TODO: ej. cola remote_write se desborda --> | <!-- --> | <!-- --> | <!-- --> |
| <!-- TODO: ej. explosión de cardinalidad por un equipo --> | <!-- --> | <!-- --> | <!-- --> |
| <!-- TODO: ej. coste de egress inter-región fuera de presupuesto --> | <!-- --> | <!-- --> | <!-- --> |

---

## Appendix (opcional)

- Objeciones recibidas en revisión y respuestas.
- Comparación con Grafana Cloud (SaaS).
- Modelo de coste a 3 años.
