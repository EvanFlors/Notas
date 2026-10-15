# tf-12 — Testing y Policy-as-Code

## Identificación

- **ID:** `tf-12-testing-and-policy-as-code`
- **Curso:** `terraform`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `tf-06` (módulos), `tf-10` (providers avanzados y lifecycle). Útil: haber leído `tf-05` (state) y `tf-11` (backends).

## Objetivo

**Validar código, infraestructura y política antes de aplicar.** Diseñar un pipeline de validación por capas (formato → sintaxis → lint → misconfig → policy sobre plan → tests nativos) y decidir qué controles exigir en PR vs en merge vs en apply.

## Alcance

Este módulo cubre:

- Validación de **sintaxis y estilo**: `terraform fmt`, `terraform validate`, **tflint**.
- Scanners de **misconfig estática sobre HCL**: **Checkov**, **Trivy config**, **Terrascan**.
- Análisis sobre el **plan JSON** (`terraform show -json plan.tfplan`) con **OPA/Rego** + **Conftest**.
- **Policy-as-code** comercial: **Sentinel** (mención, trade-offs).
- **Tests nativos**: archivos `*.tftest.hcl` (Terraform ≥ 1.6) con bloques `run`, `variables`, `assert`.
- **Terratest** (Go) para pruebas end-to-end reales (mención).
- Diseño de **gates por ambiente** (dev/stg/prod).

Lo que **no** cubre:

- Pipeline completo de CI/CD con GitHub Actions y OIDC → `tf-13`.
- Platform patterns y biblioteca Rego a escala → `tf-14`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-tflint-and-fmt/` — configuración de tflint + patrón de uso en CI.
  - `02-checkov-baseline/` — scan Checkov con baseline y skip-rules.
  - `03-conftest-rego-on-plan/` — Rego sobre `terraform show -json`.
  - `04-terraform-test-module/` — tests nativos `*.tftest.hcl`.
- **`activities/`**:
  - `01-add-validation-pipeline-locally/` — guided-lab: `pre-apply.sh` encadenando `fmt → validate → tflint → checkov → conftest`.
  - `02-write-rego-policy-no-public-s3/` — independent: policy OPA que deniega S3 público.
- **`resources/links.md`**.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar análisis estático sobre HCL (Checkov) vs análisis sobre el plan JSON (Rego). Explicar por qué el plan es un oracle más fuerte que el HCL fuente. |
| Operativa | Armar un script `pre-apply.sh` que encadene formato, sintaxis, lint, misconfig y policy; escribir policies Rego sobre un plan; escribir un `*.tftest.hcl` con `run` + `assert`. |
| Arquitectónica | Decidir qué controles exigir en PR, en merge y en apply según costo y bloqueo de desarrollo. Diseñar un gate por ambiente (dev permisivo, prod estricto). |

## Entregables

- Módulo propio con al menos un archivo `*.tftest.hcl` (plan-only y apply-based).
- Policy OPA/Rego aplicada contra el plan JSON del módulo, con fixtures que PASAN y que FALLAN.
- `pre-apply.sh` ejecutable que encadena todas las validaciones y maneja ausencia de binarios con `SKIP` explícito.

## Criterios de evaluación

- `terraform fmt -check` pasa sobre todo el módulo.
- `terraform validate` pasa.
- Hay al menos **2 reglas Rego** propias y fixtures que distinguen válido de inválido.
- Hay al menos **2 bloques `run`** en el `*.tftest.hcl` (uno `plan`, uno `apply` si es seguro sin cloud).
- El estudiante justifica por escrito qué controles correrían en PR vs merge vs apply y por qué.

## Secuencia recomendada

1. Leer `theory/lesson.md` (una pasada).
2. Reproducir `examples/01-tflint-and-fmt/` y `02-checkov-baseline/`.
3. Reproducir `examples/03-conftest-rego-on-plan/` observando el JSON del plan.
4. Reproducir `examples/04-terraform-test-module/`.
5. Hacer `activities/01-add-validation-pipeline-locally/` (guiada).
6. Hacer `activities/02-write-rego-policy-no-public-s3/` (independiente).
7. Responder las preguntas de evaluación de la lección.

## Siguiente

→ `tf-13-cicd-and-opentofu`: llevar este pipeline a GitHub Actions con OIDC y comentarios de plan en PR.
