# aws-17 — Plataforma, FinOps y Well-Architected

## Identificación

- **ID:** `aws-17-platform-finops-and-well-architected`
- **Curso:** `aws`
- **Nivel:** producción (capstone del track AWS)
- **Duración estimada:** 7 h
- **Prerrequisitos:** `aws-07` (networking avanzado), `aws-08` (datos), `aws-12` (observabilidad), `aws-15` (Organizations/IdC).

## Objetivo

Operar AWS **como plataforma**: diseñar una **landing zone** mínima pero correcta, aplicar **FinOps** con **unit economics** reales (`$/MAU`, `$/req`), aterrizar un plan de **DR** consciente de costos y hacer una **revisión Well-Architected** sobre un workload hipotético. Es un módulo **de síntesis**: no se instala nada, no se gasta un dólar; se **razona, calcula y escribe**.

## Alcance

Este módulo cubre:

- **Landing zone**: red central, DNS compartido, logging a cuenta `log-archive`, security tooling a cuenta `audit`. Patrón **hub-and-spoke** con **Transit Gateway + Route 53 Resolver**.
- **FinOps**:
  - Taggeado obligatorio (**cost allocation tags**) y por qué sin tags no hay FinOps.
  - **Savings Plans**, **Reserved Instances**, **Spot**, **Graviton** y **AWS Compute Optimizer**.
  - **Cost Explorer** (walkthrough escrito) y **Cost Anomaly Detection**.
  - **Unit economics**: pasar de `$/mes agregado` a `$/MAU`, `$/request`, `$/tenant`.
- **DR**: estrategia **RPO/RTO**, patrones **backup/restore**, **pilot-light**, **warm standby**, **multi-region active-active**, con sus trade-offs de coste.
- **Config conformance packs** y **Security Hub** (findings agregados en cuenta `audit`).
- **Well-Architected Framework**: 6 pilares (Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, Sustainability).
- **Resilience Hub** (opcional, mención).

Lo que **no** cubre:

- Instalar Control Tower o Landing Zone Accelerator reales (es un módulo escrito, no de aprovisionamiento).
- Negociar un Enterprise Discount Program (EDP) — eso es procurement, no ingeniería.
- Reemplazar un curso dedicado de ingeniería de datos o de seguridad.

Este módulo es **100 % conceptual + hojas de cálculo**. El único tooling exigido es `bash`, `python3` (con `csv` de stdlib) y un editor Markdown. **No** se ejecutan comandos AWS; no se piden credenciales; no aparecen *account IDs* reales.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-tagging-strategy-and-enforcement-scp/` — qué tags son obligatorios, cómo se exigen con **SCP** y qué pasa cuando faltan.
  - `02-savings-plan-estimation/` — cómo se razona la compra de Savings Plan vs on-demand, con una hoja de cálculo sintética.
  - `03-dr-pilot-light/` — patrón **pilot-light** paso a paso, con RPO/RTO estimados y su factura.
- **`activities/`** — tres actividades:
  - `01-landing-zone-minimal-adr/` — ADR de landing zone mínima (independiente).
  - `02-finops-dashboard-and-anomaly/` — pipeline Python sobre CSV sintético que calcula `$/MAU` y `$/req`, detecta anomalías.
  - `03-well-architected-review-and-dr-plan/` — capstone de síntesis: revisión WA de 6 pilares + plan DR razonado + walkthrough escrito de Cost Explorer.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué una landing zone **mal diseñada cuesta plata** (NAT por cuenta vs central, logs duplicados). Nombrar los 6 pilares WA y qué pregunta responde cada uno. Distinguir Savings Plan de RI y de Spot. |
| Operativa (sin infra) | Dado un CSV sintético de coste y uso, calcular `$/MAU` y `$/req` y detectar un mes anómalo. Diseñar un plan DR eligiendo entre backup/pilot-light/warm/active-active con justificación de coste. |
| Arquitectónica | Escribir un ADR de landing zone (cuentas, red, logging, security tooling) defensible. Escribir una revisión WA con **hallazgos** y **acciones priorizadas**. |

## Criterios de evaluación

- Entrega los tres entregables con validadores estructurales en verde.
- El ADR de landing zone nombra al menos las cuentas `management`, `log-archive`, `audit` y una cuenta `workload`.
- El análisis FinOps calcula `$/MAU` y `$/req` y detecta la anomalía plantada en el CSV sintético.
- El plan DR elige **un** patrón por workload con RPO/RTO razonados y una **cifra estimada** de coste mensual relativa (no un número real; una banda o un múltiplo del baseline).
- La revisión WA cubre **los 6 pilares** y produce al menos **6 hallazgos** priorizados (uno por pilar, mínimo).

## Entregables

- `LANDING-ZONE-ADR.md` (actividad 01).
- `FINOPS-REPORT.md` + CSVs derivados (actividad 02).
- `WELL-ARCHITECTED-REVIEW.md` + `DR-PLAN.md` + `COST-EXPLORER-WALKTHROUGH.md` (actividad 03).

## Siguiente módulo

Este es el **último** módulo del track AWS. Lo que sigue es el **capstone transversal** del programa (ver `projects/`), donde se integra AWS + Kubernetes + observabilidad + DevSecOps + FinOps en un único workload de referencia.

## Costos reales

**Cero.** No se crea nada en AWS. Todo el trabajo es escrito y con CSVs locales en `/tmp/aws-17-*`.
