# aws-15 — Multi-cuenta con AWS Organizations e IAM Identity Center

## Identificación

- **ID:** `aws-15-multi-account-org-identity-center`
- **Curso:** `aws`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `aws-01` (modelo global y billing), `aws-02` (IAM core), `aws-06` (IAM avanzado: roles, trust policies).

## Objetivo

Interiorizar cómo se opera una organización AWS con **múltiples cuentas** gobernadas de forma central y **acceso humano vía SSO**. Al terminar deberías poder diseñar — en papel — una organización pequeña (3–5 cuentas), decidir su estructura de OUs, aplicar un baseline de **SCPs** y conectar **IAM Identity Center** como fuente única de acceso humano, sin confundir una SCP con una identity policy, ni una Permission Set con un IAM role tradicional.

## Alcance

Este módulo cubre:

- **AWS Organizations**: management account, OUs, member accounts, creación vs invitación, consolidated billing.
- **Service Control Policies (SCPs)** como guardrails: `deny` por región, `deny leave-organization`, `deny disable-logging`; interacción con identity policies ("una SCP niega → no hay allow que la salve").
- **AWS Control Tower**: landing zone opinada (management + log archive + audit + guardrails). Qué es gratis y qué cobran los servicios subyacentes (CloudTrail, Config, S3).
- **IAM Identity Center (ex AWS SSO)**: directorio integrado (interno, Okta, Entra ID, Google Workspace), **Permission Sets** como plantillas que generan roles por cuenta, asignación a cuentas y OUs.
- Patrón **"una app = una cuenta"** vs **"una app = N cuentas (dev/stg/prod)"**; cuándo cada uno.
- **Cross-account roles** para pipelines (CI/CD) y para humanos (jump accounts).

Lo que **no** cubre (se verá después):

- Los controles DevSecOps específicos sobre esta base (OIDC GHA → AWS, Inspector, GuardDuty) → `aws-16`.
- La landing zone extendida con red central, DNS compartido y FinOps → `aws-17`.
- Terraform operativo para esta base (`org-with-tf`, módulos reutilizables) — se referencia conceptualmente pero el laboratorio en Terraform es parte de la Fase 4 del programa.

Este módulo es **mayoritariamente conceptual + ADR + validación de JSON**. **No** se provisiona nada en una cuenta real. Las dos actividades son análisis escritos y SCPs validadas estructuralmente; el único *tooling* es `bash`, `jq`, `python3` y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-ou-tree-diagram/` — árbol ASCII anotado de una organización típica (Security + Sandbox + Workloads/dev-stg-prod).
  - `02-scp-anatomy/` — anatomía de una SCP: `Version`, `Statement`, `Effect`, `Action`, `Resource`, `Condition`; patrones `deny-leave-org`, `deny-regions`, `deny-disable-logging`.
  - `03-identity-center-permission-sets/` — ciclo de vida de un Permission Set: creación en el management, asignación a (user|group, account|OU), rol materializado en la cuenta destino.
- **`activities/`** — dos actividades **independientes**:
  - `01-design-ou-structure-and-adr/` — diseñar la organización para un escenario dado y escribir un **ADR** justificando OU structure, cuentas, SCPs y modelo de acceso.
  - `02-write-scp-baseline-and-validate/` — escribir 3 SCPs del baseline (deny-regions, deny-leave-org, deny-disable-logging) en JSON y validarlas estructuralmente.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre SCP e identity policy; por qué el management account no hospeda workloads; por qué un Permission Set es una plantilla, no un rol. |
| Operativa (sin infra) | Diseñar una OU structure para 3–5 cuentas razonando trade-offs; escribir una SCP sintácticamente correcta; mapear usuarios/grupos a Permission Sets y cuentas. |
| Arquitectónica | Decidir *"una app = una cuenta"* vs *"una app = N cuentas"*; integrar un IdP externo (Okta/Entra ID) como SSO source; dibujar el flujo cross-account para un pipeline. |

## Criterios de evaluación

- Dado un diagrama de organización, identifica qué cuenta es management, cuáles de log/audit, cuáles de workloads.
- Lee una SCP y explica correctamente qué permite y qué no (incluyendo el efecto de `Condition`).
- Justifica por qué un `Allow` en una identity policy no evade un `Deny` en una SCP.
- Nombra 3 SCPs del baseline estándar y qué protegen.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `ADR-ORG-STRUCTURE.md` con decisión de OU structure, cuentas, SCPs y modelo de acceso (sale de la actividad `01`).
- Tres **SCPs** en JSON válido con nombres `scp-deny-regions.json`, `scp-deny-leave-org.json`, `scp-deny-disable-logging.json` (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto y JSON. No se requiere cuenta AWS activa. Si en una fase posterior decides provisionar lo diseñado:

- **AWS Organizations** y **SCPs**: gratis.
- **IAM Identity Center**: gratis.
- **AWS Control Tower**: el servicio es gratis, pero los servicios subyacentes que habilita (**CloudTrail organization trail**, **Config**, **S3** para logs, **KMS**) **sí** cobran. En una org pequeña real suele estar en pocos USD/mes, pero no es cero.

## Siguiente módulo

→ `aws-16-devsecops-on-aws` — controles DevSecOps aterrizados sobre esta base: OIDC GitHub Actions → AWS, Secrets Manager rotation, Inspector, GuardDuty, firma de imágenes.
