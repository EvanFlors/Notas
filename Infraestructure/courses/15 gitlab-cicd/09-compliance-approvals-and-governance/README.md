# gl-09 — Compliance, approvals y governance

## Identificación

- **ID:** `gl-09-compliance-approvals-and-governance`
- **Curso:** `gitlab-cicd`
- **Nivel:** producción (advanced)
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gl-07` (environments y Review Apps), `gl-08` (scanners y supply chain).

## Objetivo

Interiorizar cómo se **gobierna** una instalación de GitLab a nivel grupo o instance cuando el curso ya pasó de "pipelines que funcionan" a "pipelines que cumplen". Al terminar deberías poder diseñar — en papel — el baseline de gobernanza para una organización de 50 proyectos: qué **Compliance Framework** aplicas, qué **Compliance Pipeline** se concatena a cada proyecto etiquetado, qué **MR approval rules** y **Code Owners** son obligatorios, qué **protected branches** y **push rules** están activas, y cómo los **audit events** llegan a un SIEM. Nada de esto se provisiona en una instancia real; el entregable es documentación y YAML/JSON que un equipo de plataforma pueda ejecutar en Fase 4.

## Alcance

Este módulo cubre:

- **Compliance Frameworks**: etiqueta aplicada a un project desde el group settings. Define qué **Compliance Pipeline** se **inyecta** antes del pipeline del proyecto. Un project **extiende** pero no puede **omitir**.
- **Compliance Pipelines** como pipeline injection: patrón `include: $CI_PROJECT_PATH` + stages reservados (`.pre`, `.post`), ownership del pipeline en manos del equipo de compliance.
- **MR Approval Rules**: número mínimo de approvers, **Code Owners** obligatorios por path, **security approvals** condicionadas por findings de SAST/DAST/Dependency, bloqueo de self-approval.
- **Protected branches/tags**: quién puede push, quién puede merge, `code_owner_approval_required`, firmas GPG.
- **Push rules** (Premium/Ultimate): regex de commit message (p. ej. `JIRA-\d+`), rechazo de archivos `*.pem`, `.env`, tamaño máximo, autor obligatorio del dominio corporativo.
- **Audit events**: qué eventos emite GitLab por project/group/instance, cómo exportarlos a SIEM (Splunk, Elastic, Datadog) vía streaming audit events.
- **RBAC**: roles `Guest / Reporter / Developer / Maintainer / Owner` y cómo mapean al día a día.
- **SSO**: SAML + **SCIM** para provisioning automático desde Okta/Entra ID; **IP allowlist** por group.
- **License tier awareness**: qué features son Free, Premium, Ultimate.

Lo que **no** cubre:

- La **migración** entre GHA y GitLab, y el `CI/CD Catalog` como plataforma → `gl-10`.
- Los scanners nativos y la firma de imágenes → ya vistos en `gl-08`.
- Deployments y Review Apps → ya vistos en `gl-07`.

Este módulo es **mayoritariamente conceptual + ADR + validación de YAML/JSON**. **No** se aplica nada en una instancia real. Las dos actividades son un *guided-lab* (escribir el skeleton de un compliance pipeline + rules.yml) y un ADR de gobernanza. El único *tooling* es `bash`, `yq`, `jq`, `python3` y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-compliance-framework-anatomy/` — anatomía de un Compliance Framework: etiqueta, pipeline inyectado, cómo el project lo extiende y qué puede/no puede sobreescribir.
  - `02-mr-approval-rules-matrix/` — matriz de reglas: approvers mínimos, Code Owners obligatorios, security approvals, self-approval bloqueado.
  - `03-audit-events-and-push-rules/` — ejemplos de eventos de auditoría clave (`protected_branch_updated`, `user_access_granted`...) y push rules típicas (regex de commit, deny de `.pem`).
- **`activities/`** — dos actividades **independientes**:
  - `01-apply-compliance-framework/` — escribir el skeleton de un Compliance Pipeline (`compliance-pipeline.yml`), un `CODEOWNERS`, un `approval-rules.yml` y aplicar el framework al grupo. Validador estructural.
  - `02-governance-adr/` — escribir un **ADR** proponiendo un baseline de gobernanza para una org de 50 proyectos.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre un Compliance Pipeline (inyectado por el grupo) y un `include:` normal; por qué un project no puede omitir el framework; por qué `code_owner_approval_required` es ortogonal al número de approvers. |
| Operativa (sin infra) | Escribir un `compliance-pipeline.yml` que corra SAST+Secret Detection obligatorios; redactar un `CODEOWNERS` y un `approval-rules.yml` coherente; proponer push rules concretas. |
| Arquitectónica | Diseñar un baseline de gobernanza para 50 projects reconciliando compliance, DX y coste; justificar el tier (Premium vs Ultimate) necesario; dibujar el flujo de audit events hasta un SIEM. |

## Criterios de evaluación

- Dado un proyecto etiquetado con un framework, explicar qué pipeline corre primero y qué garantías aporta.
- Leer un `approval-rules.yml` y explicar quién debe aprobar qué MR.
- Nombrar al menos 3 **push rules** del baseline y qué protegen.
- Nombrar al menos 3 **audit events** críticos para un auditor.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Compliance Pipeline** skeleton `compliance-pipeline.yml` + `CODEOWNERS` + `approval-rules.yml` + `README-INTENT.md` (sale de la actividad `01`).
- **ADR** `ADR-GOVERNANCE-BASELINE.md` con decisión de framework, approval rules, push rules, SSO y audit (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, YAML y JSON. No se requiere instancia GitLab activa. Si en una fase posterior decides aplicarlo:

- **Compliance Frameworks / Compliance Pipelines**: requieren **Premium** (framework básico) o **Ultimate** (pipeline injection).
- **MR Approval Rules** avanzadas (Code Owners obligatorios, security approvals por findings): **Ultimate**.
- **Push Rules** (regex, deny de archivos): **Premium**.
- **Audit events streaming** a SIEM: **Ultimate**.
- **SAML/SCIM**: incluido desde Premium.

## Siguiente módulo

→ `gl-10-migration-and-platform-patterns` — migración GHA ↔ GitLab y operación del CI/CD Catalog como plataforma.
