# gha-11 — OIDC y federación con clouds

## Identificación

- **ID:** `gha-11-oidc-and-cloud-federation`
- **Curso:** `github-actions`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gha-05` (secrets, variables, `GITHUB_TOKEN`, `permissions:`), `gha-09` (environments y approvals).

## Objetivo

Eliminar las credenciales de larga vida (`AKIA…`, Service Account keys, Client Secrets) del CI/CD. Cada workflow pide un **id-token OIDC** firmado por GitHub, lo canjea en el cloud por credenciales efímeras (≤ 1 h) a través de la relación de confianza (**trust policy**) definida en IAM/WIF/Entra ID. Al terminar el workflow, las credenciales expiran: no hay nada que rotar, no hay nada que leakear a largo plazo.

## Alcance

Este módulo cubre:

- Qué emite GitHub Actions como **OIDC token** y qué claims contiene (`iss`, `sub`, `aud`, `repository`, `ref`, `environment`, `workflow`, `job_workflow_ref`, `actor`, `run_id`).
- Cómo lo canjea por credenciales cada cloud:
  - **AWS**: `sts:AssumeRoleWithWebIdentity` + OIDC provider en IAM + trust policy.
  - **GCP**: Workload Identity Federation (`workloadIdentityPools` + `workloadIdentityProviders` + Service Account impersonation).
  - **Azure**: Federated Identity Credentials en una App Registration / Managed Identity.
- Cómo escribir **condiciones del trust** basadas en claims. Patrones **buenos** (pin a `repo+branch` o `repo+environment`) y **patrones vulnerables** (pin solo al owner, pin con wildcard de rama, pin solo con `audience`).
- Interacción con `permissions: id-token: write` en el workflow y con `environment:` del job.
- Auditoría de trust policies: cómo detectar los antipatrones en revisión.

Lo que **no** cubre (se asume de módulos previos o posteriores):

- `permissions:` del `GITHUB_TOKEN` → se vio en `gha-05`.
- Environments y approvals → `gha-09`.
- Hardening general de workflows (pinnear SHA, `pull_request_target`) → `gha-13`.

Este módulo **profundiza** sobre lo visto en `gh-13-03-oidc-federation-to-cloud` del curso Git/GitHub, llevando la federación a GCP y Azure, y añadiendo la auditoría activa de trust policies vulnerables.

## Temas y subtemas

1. Problema que resuelve OIDC en CI.
2. Anatomía del id-token emitido por GitHub Actions.
3. Flujo de intercambio por cloud (AWS, GCP, Azure).
4. Trust policy: dónde se define y qué compara.
5. Pinning seguro vs antipatrones.
6. Interacción entre `environment:` del job y el claim OIDC.
7. Auditoría activa: cómo revisar una trust policy en PR.

## Conceptos internos (fundamentos)

- Flujo HTTP paso a paso del intercambio (dónde se firma, dónde se verifica, qué JWKS se consulta).
- Por qué un trust mal escrito permite **cross-tenant abuse** (otro repo de otra organización asumiendo tu rol).
- Relación entre `environment:` del job y el claim `sub` resultante.
- Rotación: en el modelo OIDC *no* hay rotación de credenciales — las credenciales viven lo que vive el run.

## Competencias

- **Conceptual:** describir el flujo OIDC paso a paso ante AWS, GCP y Azure. Explicar qué garantiza (y qué *no* garantiza) una trust policy correcta.
- **Operativa:** federar un workflow con AWS (y, por extensión, con GCP/Azure) sin ningún secret estático; escribir trust policies con pin seguro.
- **Arquitectónica:** auditar trust policies ajenas y clasificarlas como seguras / vulnerables, proponiendo la corrección exacta.

## Ejemplos

- [`examples/01-oidc-aws-assume-role/`](examples/01-oidc-aws-assume-role/) — Trust policy IAM + workflow completo que asume el rol en AWS.
- [`examples/02-trust-policy-with-environment-claim/`](examples/02-trust-policy-with-environment-claim/) — Mismo rol pero pinneado por `environment:production`, mostrando cómo se combina con approvals de GitHub.

## Actividades

- [`activities/01-federate-with-aws/`](activities/01-federate-with-aws/) — Guided-lab **dual-mode**: construyes el patrón OIDC completo (trust policy + workflow) y lo validas localmente; opcionalmente lo despliegas en una cuenta AWS real.
- [`activities/02-review-vulnerable-trust-policy/`](activities/02-review-vulnerable-trust-policy/) — Independiente: te dan 4 trust policies con problemas (algunos obvios, otros sutiles). Las clasificas, explicas por qué cada una es vulnerable y escribes la versión corregida.

## Entregables

- Repo (o directorio) con workflow que despliega a AWS vía OIDC, **sin ningún secret estático** y con trust policy pinneada a `repo+environment`.
- Informe de auditoría de 4 trust policies (actividad 02), con la corrección propuesta de cada una.

## Criterios de evaluación

| Dimensión | Nivel esperado |
|---|---|
| Flujo | Describe los pasos del intercambio OIDC → STS/WIF/Entra, incluyendo qué firma GitHub, qué verifica el cloud, qué devuelve. |
| Seguridad | Pin del `sub` siempre al menos a `repo:Org/Repo:*` con restricción adicional (`:ref:…` o `:environment:…`). Nunca pin solo al owner, nunca wildcard después del nombre del repo. |
| `permissions:` | `id-token: write` solo en el job que lo necesita; `contents: read` por defecto top-level. |
| Reproducibilidad | Trust policy y workflow se recrean desde el repo sin pasos manuales ocultos. |
| Auditoría | Clasifica correctamente los 4 trust policies vulnerables y propone fix mínimo. |

## Recursos

Ver [`resources/links.md`](resources/links.md).
