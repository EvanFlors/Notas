# Ejercicio arquitectónico — Diseñar la plataforma del año 1 de ACME

> Duración sugerida: 35-45 min dentro del examen. Entregable: `architectural/response.md` + `architectural/ADR-001-plataforma-ano-uno.md`.

## Contexto organizacional

ACME es una fintech regional con:

- **42 microservicios** en producción, repartidos en **9 equipos stream-aligned** (payments, growth, risk, fraud, data, ops, mobile, core-api, bff).
- Hoy existe un **equipo "DevOps" de 4 personas** que opera clusters EKS, pipelines GHA compartidos y Argo CD; recibe tickets todo el día y es cuello de botella.
- CTO acaba de aprobar transformar ese equipo en un **platform team** y **sumar 3 personas** (total 7). Presupuesto cloud razonable; **no** hay licencia de Port/OpsLevel/Cortex aprobada todavía — hay que justificarla si se pide.
- Stack actual: EKS, Argo CD, GHA, Terraform (gestionado por el propio DevOps team con PRs manuales), Grafana+Prometheus, PagerDuty.
- Dolor reportado por developers (DX survey): "crear un servicio nuevo lleva 2-3 semanas", "no sé dónde buscar runbooks", "cambios de infra tardan por review manual".
- Hiring freeze a **9 meses vista** es un riesgo plausible (anotado por el CFO).
- Hay un **M&A probable** a 12 meses que agregaría ~15 servicios en stack distinto (GCP, Cloud Build).

## Tu tarea

Diseñar y defender el **plan de plataforma del año 1**. Produces dos documentos:

### 1. `response.md` (diseño + trade-offs)

Debes cubrir, con razonamiento explícito (no checklists):

1. **Team Topologies de ACME** post-transformación.
   - ¿El platform team es stream-aligned, enabling, platform o complicated-subsystem? Justifica.
   - ¿Qué modos de interacción (X-as-a-Service, collaboration, facilitating) usará con cada equipo stream-aligned, y por qué el default debe ser X-as-a-Service?
   - Nombra al menos 2 antipatterns que el equipo debe evitar y cómo los prevendrás.

2. **Primer golden path**.
   - Elige UNO (no tres) y defiéndelo con los 4 criterios del módulo (volumen, variabilidad baja, dolor compartido, impacto medible).
   - Define qué pasa con el **long tail** (servicios fuera del golden path): opción B soportada vs no soportada, y por qué.
   - Explicita: ¿es opt-in o mandato? ¿Por qué esa elección hoy?

3. **IDP: elegir herramienta**.
   - Compara Backstage self-hosted vs CNOE vs Port vs seguir sin IDP durante 6 meses.
   - Recomienda UNA opción y justifica contra las **restricciones concretas** del escenario (7 personas, M&A en 12 meses, no licencia aprobada).
   - Especifica qué 3 plugins/features priorizarías en el primer trimestre.

4. **Self-service de infra: Crossplane vs Terraform-via-PR (Atlantis o GHA)**.
   - Recomienda con criterio del módulo (org K8s-first vs TF-first). ACME ya usa EKS y TF; el equipo plataforma tiene 7 personas; el M&A traería GCP.
   - Define el conjunto mínimo de recursos self-service para el trimestre 1 (máximo 3). Nombra guardrails (Kyverno, policies, labels de FinOps).

5. **Scorecards + DORA + SPACE**.
   - Define 5-8 checks iniciales de scorecard (no 20) y explicita el peso.
   - Lista 4 DORA metrics y qué 2 señales de SPACE añadirías para que no caiga en Goodhart's Law.
   - ¿Qué métrica NO vas a reportar en el dashboard ejecutivo y por qué (anti-vanity)?

6. **Platform-as-product y gobernanza**.
   - Modelo de financiamiento (showback, chargeback, platform fee, "gratis"). Elige y defiende.
   - Deprecation policy con TTL (ciclo announce → warn → remove, en días) y canal.
   - 3 platform SLOs defendibles (uno de disponibilidad de Backstage, uno de latencia del scaffolder, uno de freshness del catalog).
   - Modelo de inner-source: ¿cómo escalas sin crecer el equipo linealmente?

7. **Trade-offs explícitos y defensa de 3 escenarios**:
   - **Crecimiento rápido** (duplicar servicios en 12m): qué se rompe de tu plan.
   - **Hiring freeze a 9 meses**: qué recortas y qué defiendes.
   - **M&A con stack GCP/Cloud Build**: cómo acomoda tu plan la deuda de integración.

### 2. `ADR-001-plataforma-ano-uno.md`

ADR formal (Context / Decision / Status / Consequences / Alternatives considered) que resuma las decisiones vinculantes del plan: elección IDP, Crossplane vs TF-via-PR, modelo de financiamiento, platform SLOs.

## Rúbrica (ver sección 5 del EXAM.md)

Se evalúa principalmente **razonamiento y trade-offs**, no completitud. Un plan "razonable y defendible con 2-3 limitaciones explícitas" vale más que un plan "perfecto en papel sin tensiones admitidas".
