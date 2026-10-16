# REFERENCE — plat-03-01-tool-choice-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte. Otra decisión defendible (Port o CNOE) también sería válida con argumentos equivalentes.

---

# ADR-001: Selección de IDP para Acme Fintech

## Status

Accepted — 2026-Q1

## Context

Acme Fintech opera **~250 developers** en 40 microservicios (70% Go, 25% Python, 5% TS/React en frontends) sobre **EKS multi-tenant** en dos regiones. El platform team acaba de formarse: **3 ingenieros** con perfiles **mixtos K8s/Go**; solo 1 tiene experiencia TS real. No hay portal interno; el catálogo de servicios vive en una hoja de Google desactualizada.

El CTO exige una decisión en 2 semanas. **Port** envió una demo con pricing cerrado si firmamos antes de fin de trimestre. Compliance permite SaaS para herramientas internas no-productivas. El horizonte de planeación es **18–24 meses**.

Fuerzas en juego:

- **Time-to-first-value** exigido: valor demostrable en 90 días para defender el presupuesto del platform team ante finance.
- **TCO**: budget capex de 3 FTE + ~$60k anuales en software. Opex per-developer razonable hasta 400 devs.
- **Lock-in**: la decisión debe ser **reversible** en 18–24 meses sin reescribir el catálogo.
- **Adopción**: engineering leads escépticos con "otra herramienta más"; necesitamos quick wins.

## Decision

Elegimos **Port** como IDP de referencia para los próximos 18–24 meses, con **plan explícito** de reevaluar migración a **Backstage self-hosted** al llegar a 400 developers o si la extensibilidad empieza a doler.

## Alternatives considered

- **Backstage self-hosted** — descartada **hoy** por bandwidth: 3 ingenieros con 1 solo TS-literate no sostienen el day-2 (upgrades de Backend System, parches de plugins, soporte interno). El TCO real supera los $300k/año en salarios dedicados vs el opex equivalente de Port a 250 devs. Reconsideración activa en 18 meses cuando el equipo crezca.
- **CNOE** — descartada por **expertise CNCF insuficiente** en el equipo actual (solo 1 ingeniero fluente en Argo CD + Crossplane). CNOE ordena la stack pero **no reduce** la carga de operación de 5 componentes. Habría sido la opción si tuviéramos 5+ ingenieros CNCF-nativos.
- **OpsLevel** — descartada: su valor principal (scorecards) resuelve un problema **secundario** para nosotros. El problema primario es *inventario + onboarding*, no madurez. OpsLevel sería mejor para una organización con portal maduro que necesita elevar su baseline.
- **Humanitec** — descartada: resuelve el "muchos entornos deriva" problem, que no es el nuestro (tenemos dev/stg/prod y nada más). Podría convivir con Port en el futuro si el problema aparece.
- **Cortex** — descartada por **traslape fuerte con OpsLevel** y mismo diagnóstico: scorecards-first no es nuestro dolor principal.

## Consequences

### Positivas

- **Time-to-value: 2 semanas** para portal usable con 40 servicios catalogados vía integración GitHub nativa.
- **El platform team libera 100% de su tiempo** para construir golden paths (Scaffolder actions → GHA), scorecards y templates, en vez de operar el portal.
- **Costo predecible**: pricing per-dev conocido, cabe en budget hasta 400 devs sin renegociar.
- **Scorecards nativos** utilizables desde día 1 sin plugin setup.

### Negativas (aceptadas)

- **Lock-in medio-alto**: los blueprints, actions y scorecards viven en el modelo de Port. **Mitigación**: exportar blueprints mensualmente a Git (`platform-blueprints` repo) y mantener documentación de modelado que sobreviva a una migración.
- **Techo de extensibilidad**: no podremos construir plugins embebidos tipo *Backstage K8s plugin*. **Mitigación**: documentar casos de uso que empujen el techo y usarlos como señal de "ya es hora de evaluar Backstage".
- **Dependencia de vendor**: cambios de pricing o features son del vendor. **Mitigación**: contract review anual + backup plan documentado.
- **Riesgo de "portal vacío"**: Port sin golden paths es un wiki tipado caro. **Mitigación**: no lanzar portal hasta tener 2 templates productivos y 3 scorecards activos.

## Follow-ups

- **Medir platform NPS a 90 días post-launch** — dueño: PE lead. Target: ≥ 7/10.
- **Primer template productivo "nuevo microservicio Go"** en 60 días — dueño: PE engineer #1 + eng lead de dominio.
- **Export mensual de blueprints a Git** desde el día 1 — dueño: PE engineer #2 (automatizar en 30 días).
- **Revisión formal del ADR en 12 meses** — dueños: PE lead + CTO. Triggers de reevaluación anticipada: (a) equipo PE ≥ 6 ingenieros, (b) 3 casos documentados donde el techo de extensibilidad bloquea un golden path.
- **Backup plan de migración documentado a 18 meses** — todo el PE team.
- **Negociar contract con cap de pricing** a 400 devs para evitar sorpresas.

## Non-technical criteria weighed

- **TCO** (capex vs opex): el break-even entre Port y Backstage self-hosted a 250 devs favorece Port; a 500 devs se invierte. Decisión alineada con el horizonte 18 meses.
- **Hiring**: en nuestro mercado conseguir ingenieros TS/React fuertes es más caro y lento que ampliar perfiles K8s/Go. Backstage habría presionado al hiring plan.
- **Adopción interna**: los engineering leads están cansados de "proyectos de plataforma de 12 meses sin entregables". Port permite un entregable en 2 semanas.
- **Deprecations / reversibilidad**: Port acepta exportar modelado; la inversión en blueprints se traslada parcialmente a Backstage si migramos.
- **Vendor relationship**: contrato anual con cláusula de salida sin penalización; evitamos lock-in contractual aunque haya lock-in técnico moderado.

## Notes para defensa ante presión comercial

Si Vendor X (Port en este caso) presiona por "más features" o OpsLevel presiona por "pero los scorecards son mejores":

- *"Elegimos Port **hoy** porque resuelve nuestro problema primario (inventario + onboarding en 90 días) sin pedir ingeniería que no tenemos. Scorecards avanzados son un problema secundario que podemos cubrir con los nativos de Port o con un plugin más adelante. La decisión es revisable en 12 meses con criterios definidos."*

Si otro vendor presiona por "pero Backstage es el estándar":

- *"Backstage es un estándar de **framework**, no de **producto**. Adoptarlo con nuestro equipo actual produciría un fork técnico en 6 meses. Reevaluamos en 18 meses con equipo ampliado."*
