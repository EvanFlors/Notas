# sec-14 — Platform patterns, gates, DX, inventory y vuln management lifecycle

## Identificación

- **ID:** `sec-14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle`
- **Curso:** `devsecops`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `sec-05` (SCA/Trivy), `sec-09` (cosign/sigstore), `sec-11` (Kyverno/VAP), `sec-13` (Vault/ESO/WI).

## Objetivo

Operar DevSecOps como **plataforma** sin matar la DX. Este módulo es el **capstone de síntesis** del curso: no introduce una herramienta nueva, sino que compone todo lo visto (SCA, SAST, firma, admisión, secretos) bajo un **contrato de plataforma** con *gates*, *exception policy*, *SBOM inventory* y un **vuln management lifecycle** con SLA tiers y MTTR medibles.

Al terminar deberías poder:

- Redactar el **contrato de seguridad** de una plataforma (qué bloquea el merge, qué solo *warn*, qué corre nightly).
- Diseñar una **política de severidad** combinando CVSS + EPSS + KEV, no sólo CVSS.
- Formalizar una **exception policy** con approver, TTL y revisor.
- Operar el **ciclo detect → triage → prioritize → remediate → verify → report** con **SLA tiers** y **MTTR** como SLO.
- Modelar un **inventario SBOM** (asset DB / CMDB-lite) que permita responder "¿quién corre log4j 2.14?" como una query.
- Priorizar **developer experience**: feedback <10 min, supresión self-service auditable, "no sorpresas en prod".

## Alcance

Este módulo cubre:

- **Gates como contrato**: el pipeline no es una colección de scanners sueltos, es un **contrato** entre plataforma y producto; qué controles son *blocking*, cuáles son *warn-only* y cuáles son *out-of-band* (nightly, baseline).
- **Política de severidad SLO-driven**: por qué "fallar en Medium" quema a los equipos y por qué EPSS + KEV son mejores *gating signals* que CVSS puro.
- **Exception policy** formal: approver (ownership claro), TTL (toda excepción expira), compensating controls, auditoría. Sin esto las excepciones se vuelven *regla implícita*.
- **SBOM como inventario**: publicar SBOMs a un **store centralizado** (base de datos indexable), con la pregunta canónica "¿qué servicios cargan la librería X versión Y?" resuelta en segundos.
- **Vuln management lifecycle** completo con **SLA tiers** (Critical=24h, High=7d, Medium=30d, Low=next release) y **MTTR** medido por tier.
- **Métricas DevSecOps**: MTTR, mean time to patch, % imágenes firmadas, % pipelines con todos los gates, % cobertura de SBOM, backlog por tier.
- **Developer experience**: feedback <10 min, mensajes accionables, supresión self-service con justificación auditable, integración con **IDP** (Backstage security tab).
- **Golden path CI de referencia**: pipeline minimal con secret scan + SAST + SCA + container scan + SBOM + firma, con **SARIF agregado** subido a GitHub Code Scanning (único panel).
- **Gobernanza**: reviews quarterly, drift de policies, deprecation window.

Lo que **no** cubre:

- Cómo instalar/operar cada scanner individualmente — eso está en `sec-04`..`sec-12`.
- Cómo instrumentar Backstage — fuera del scope DevSecOps (es un curso IDP distinto).
- Cómo levantar un data warehouse para el inventory store — ejemplo conceptual con schema SQL ilustrativo.
- Cálculo real de EPSS/KEV en vivo contra NVD — se usan fixtures ilustrativos.

Este módulo es **mayoritariamente conceptual + ADR-driven**. Las dos actividades son documentos razonados (`ADR` y proceso de vuln management), no infraestructura. Los *examples* son referencias textuales y un workflow YAML de ejemplo.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones (gates, severidad, exceptions, inventory, lifecycle, métricas, DX, gobernanza).
- **`examples/`**:
  - `01-gates-contract/` — TEMPLATE.md de contrato de seguridad + workflow YAML de referencia (`golden-path.yml`) con SARIF agregado a GitHub Code Scanning.
  - `02-sbom-inventory-store/` — REFERENCE.md con schema SQL ilustrativo del inventory + 6 queries canónicas ("¿quién corre openssl 3.0.x?").
  - `03-vuln-mgmt-dashboard/` — REFERENCE.md con las 7 métricas base + layout ASCII del dashboard + fórmulas y target SLOs.
- **`activities/`** (independientes entre sí):
  - `01-platform-security-contract-adr/` — redactar un ADR con el contrato de gates, política de severidad, exception policy.
  - `02-vuln-mgmt-process-exercise/` — redactar el proceso operativo del vuln management lifecycle con SLA tiers, roles y métricas.
- **`resources/links.md`** — referencias oficiales (SLSA, EPSS, KEV, SARIF, Backstage).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué CVSS solo es insuficiente y cómo EPSS+KEV cambian la priorización. Definir "gate blocking vs warn vs nightly". Diferenciar inventario (SBOM) de historia (provenance). |
| Operativa | Diseñar un contrato de gates, una exception policy con TTL, un lifecycle con SLA tiers, y 7 métricas DevSecOps base. |
| Arquitectónica | Defender el contrato de plataforma ante presión *velocidad vs seguridad vs costo* usando SLOs, no slogans. |

## Criterios de evaluación

- Redacta un ADR del contrato de seguridad con decisiones trazables (contexto, opciones, decisión, consecuencias).
- La política de severidad propuesta combina CVSS + EPSS + KEV y justifica umbrales.
- La exception policy define approver, TTL y revisor nominados.
- El proceso de vuln management nombra las 6 etapas, SLA por tier y MTTR como SLO.
- Las dos actividades pasan la validación estructural (`bash tests/validate.sh`).

## Entregables

- `ADR-security-contract.md` (actividad 01).
- `VULN-MGMT-PROCESS.md` (actividad 02).

## Siguiente módulo

Este es el **último módulo** del roadmap `devsecops`. Los entregables de este módulo deberían integrarse en el **capstone** de la academia.
