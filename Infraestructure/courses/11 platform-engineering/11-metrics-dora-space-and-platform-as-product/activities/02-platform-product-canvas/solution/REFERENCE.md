# REFERENCE — plat-11-02-platform-product-canvas

> Una **referencia** razonada. No es la única respuesta correcta — tu canvas puede diferir sensatamente.

## CANVAS modelo — "Acme Platform (Q4 2026)"

## Sección 1 — Visión y propuesta de valor

- **Para quién:** stream-aligned teams de Acme que construyen microservicios en Python/Go.
- **Qué dolor resuelve:** el tiempo entre tener una idea de servicio y verlo en producción (hoy: 2 semanas; objetivo: 2 días).
- **Cómo se mide el éxito:** % de servicios nuevos nacidos vía template + DORA del portafolio + Platform NPS.
- **Qué NO hace:** no reemplaza al equipo de seguridad; no decide arquitectura de dominio; no provee ML/MLOps (fuera de scope este año).

## Sección 2 — Usuarios y no-usuarios

- **Persona 1 — Dev backend Python/Go** en stream-aligned team: su golden path es crear un servicio nuevo en Backstage y tener CI/CD, Helm chart, catálogo y docs listos en 1 día.
- **Persona 2 — Tech lead** de un dominio: usa el catálogo para ver dependencias y el scorecard para priorizar deuda técnica.
- **Persona 3 — SRE** del enabling team: usa el platform para desplegar probes/dashboards estándar sin copy-paste.
- **No-usuario explícito:** el equipo de **ML/data science** que vive en Databricks + Terraform propio. Está bien que no la use: el volumen (3 pipelines) no justifica integrarlos este año; los re-evaluamos en Q4 2027.

## Sección 3 — Roadmap now / next / later

### NOW (Q4 2026 comprometido)

- Postgres self-service v2 (Crossplane) — criterio: dev crea DB en Backstage en <5 min.
- Template microservicio Go — criterio: paridad con el de Python; adopción medida.
- Deprecar `legacy-flask` template — criterio: 0 servicios lo usan en create a 2026-12-31.

### NEXT (candidato Q1 2027)

- FinOps dashboard por Component.
- Blackbox probe self-service.
- Argo CD multi-cluster.

### LATER (señal sin capacidad)

- Soporte Kotlin.
- Portal interno de APIs.
- Platform CLI (`acme-plat`).

## Sección 4 — Modelo de financiamiento

- **Modelo elegido:** **showback** durante el primer año; evaluar chargeback para Q1 2028.
- **Justificación:** el consumo (DBs, buckets, pipelines) todavía no está estable. Chargeback prematuro incentiva a los equipos a **no** usar la plataforma para evitar el gasto, lo opuesto del outcome que queremos.
- **Riesgo del modelo:** el consumo invisible al equipo que lo origina no cambia comportamiento.
- **Mitigación:** showback **con cara**: cada tech lead recibe un digest mensual con el gasto de su dominio y el ranking relativo. Peer pressure sin fricción financiera.

## Sección 5 — Las 7 métricas

| # | Métrica | Categoría | Qué mide | Riesgo-Goodhart | Mitigación |
|---|---------|-----------|----------|-----------------|------------|
| 1 | Deployment Frequency (mediana portafolio) | DORA | Throughput agregado | Deploys triviales inflados | Reportar siempre junto a CFR; excluir deploys que no cambian artefacto |
| 2 | Lead Time for Changes (mediana por servicio) | DORA | Fricción del pipeline | Reducir forzando merges sin review | Mostrar junto a review-time y CFR |
| 3 | Change Failure Rate (90d rolling, portafolio) | DORA | Calidad de release | "Esconder" incidents re-etiquetándolos | Definición escrita de incident (SEV1-SEV3) y auditoría trimestral |
| 4 | Satisfaction (SPACE S): Platform experience score | SPACE | Experiencia subjetiva trimestral | Encuestar solo a amigos | Encuesta anónima, respuesta forzada en all-hands, ratio de respuestas publicado |
| 5 | % servicios registrados en catalog | Adoption | Alcance real de la plataforma | Registrar servicios muertos | Flag "last-deploy > 90d → stale"; stale cuenta pero se muestra aparte |
| 6 | Time to first prod deploy (p50, nuevo servicio) | Adoption | Promesa de valor del golden path | Pre-cocinar servicios de ejemplo | Medir solo servicios creados por equipos no-platform |
| 7 | Platform NPS (promoters − detractors) | NPS | Likelihood to recommend | Celebrar número sin leer comentarios | Reporte publicado incluye top-3 quejas verbatim |

**Dimensión A (Activity) deliberadamente NO está** en la lista. Es la más fácil de medir y la más fácil de gamificar; se mantiene en un dashboard interno del platform team pero **no** se eleva al CTO.

## Sección 6 — 3 antipatterns a evitar

1. **Celebrar DF aisladamente.** El par velocidad/estabilidad es sagrado. Si DF sube y CFR también sube, la plataforma empeoró. **Goodhart's Law**: si bonificamos DF, obtenemos commits de whitespace. Siempre juntas, siempre.
2. **"Tickets cerrados por el platform team" como KPI.** Mide el output del platform team, no el outcome del dev. Una plataforma excelente **genera menos tickets** porque el self-service funciona; medir resolución de tickets premia el *failure mode*. **Vanity metric** clásico.
3. **NPS reportado sin la ratio de respuesta ni los verbatim.** Un NPS de +40 con 12 % de response rate y sin leer los comentarios es decoración de corporate deck, no señal. Si el ratio de respuesta cae, el NPS pierde validez antes que el número.

## Sección 7 — Pregunta inicial del próximo trimestre

> Hipótesis: *"Creemos que lanzando el template Go bajamos el time-to-first-deploy de equipos no-Python de 5 días a <2 días en 90 días. Lo validamos midiendo p50 para los primeros 10 servicios Go nuevos. El experimento falla si p50 > 3 días o si <5 servicios Go nuevos nacen en el trimestre."*

## Qué NO está en este modelo (y por qué)

- **No hay un "platform health score" compuesto.** Combinar 7 métricas en un número único destruye la información y oculta gaming.
- **No hay un objetivo "subir el NPS en +N" explícito.** Convertir NPS en target es el camino directo a *survey fatigue* y respuestas infladas.
- **No hay DORA FDRT en la lista final.** Elegimos 3 DORA (DF/LTC/CFR) y dejamos FDRT en el dashboard interno. Es defendible mantener FDRT en lugar de LTC si tu organización sufre más por recuperación lenta que por lead time largo — decisión contextual.
