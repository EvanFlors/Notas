# tf-13 — CI/CD de Terraform y OpenTofu

## Identificación

- **ID:** `tf-13-cicd-and-opentofu`
- **Curso:** `terraform`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `tf-11-remote-backends-and-locking`, `tf-12-testing-and-policy-as-code`, curso **github-actions** ≥ `gha-11-oidc-and-cloud-federation`.

## Objetivo

Operar Terraform (o OpenTofu) desde CI/CD con **credenciales efímeras OIDC**, pipeline **PR → plan comentado** y **merge → apply con approval**, y evaluar OpenTofu como alternativa a Terraform a nivel de organización.

## Alcance

Este módulo cubre:

- Patrón canónico GitOps de infra: `fmt` + `validate` + `plan` en PR, comentado en el hilo; `apply` en merge a `main`, bloqueado por un GitHub Environment con *required reviewers*.
- **OIDC a cloud** (sin `AKIA...` ni service account keys) sobre lo visto en `gha-11`, pero aplicado al rol que ejecuta `terraform plan` y `terraform apply`.
- **Plan guardado como artefacto** (`-out=plan.tfplan`) que se aplica tal cual en el job de apply — el único mecanismo robusto para evitar TOCTOU entre lo que se revisó y lo que se aplicó.
- Coherencia de versión mediante `required_version`, lockfile `.terraform.lock.hcl` versionado, y setup-step (`hashicorp/setup-terraform` u `opentofu/setup-opentofu`) con versión fijada.
- **Drift detection** en un job programado (`schedule:` cron) con `terraform plan -refresh-only -detailed-exitcode` que notifica a Slack/Issues si detecta deriva.
- **OpenTofu**: historia (fork tras cambio a BUSL en 2023), licencia Apache 2.0 bajo Linux Foundation, instalación, compatibilidad del state y de providers con el Registry propio, divergencias actuales relevantes (state encryption nativa, `removed` block más agresivo, provider-defined functions), criterios de migración.

Lo que **no** cubre (otros módulos):

- Mecánica OIDC → cloud en profundidad → `gha-11`.
- Policy-as-code / `terraform test` → `tf-12`.
- Módulo registry interno, drift management operativo, golden paths → `tf-14`.

## Temas y subtemas

1. Pipeline canónico PR → plan, merge → apply.
2. OIDC a cloud en los jobs de Terraform.
3. Plan como artefacto reproducible y el problema TOCTOU.
4. Versión fija: `required_version`, lockfile, setup-action.
5. Comentarios de plan en el PR (acción oficial o custom).
6. Environment gating: approvals y branch protection coherente.
7. Scheduled drift detection (`-refresh-only -detailed-exitcode`).
8. Riesgos de los runners self-hosted compartidos.
9. OpenTofu: por qué existe, licencia, estado del Registry.
10. Compatibilidad state/providers Terraform ↔ OpenTofu.
11. Divergencias actuales (state encryption nativa, `removed` block, provider-defined functions).
12. Criterio de migración y ADR Terraform vs OpenTofu.

## Conceptos internos (fundamentos)

- **Por qué el plan guardado se aplica tal cual.** Entre `plan` y `apply` hay una ventana en la que la realidad del cloud puede cambiar. Si el apply recalcula el plan, se aplica *otro* plan — distinto al que revisó el humano. Guardar el plan binario y pasárselo intacto a `terraform apply plan.tfplan` cierra esa ventana (TOCTOU, *time-of-check vs time-of-use*).
- **Por qué compartir credenciales en self-hosted runners es peligroso.** Un self-hosted runner con creds AWS inyectadas en el entorno queda expuesto a cualquier workflow que pueda ejecutarse en él (incluido un workflow de un fork en `pull_request_target` mal configurado, o un job de otro repo del mismo pool). OIDC + runners efímeros reduce la ventana a la duración del job y restringe el `sub` del trust a un repo+environment concreto.
- **Coherencia versión-TF.** Si el PR se abre con un contributor usando TF 1.6 y el pipeline usa 1.9, se puede producir drift artificial de providers o cambios de serialización del state. `required_version` + lockfile + versión fijada en el setup-action elimina esa clase de incidentes.
- **Drift detection separada del plan de PR.** El plan de PR corre contra el código del PR; el drift job corre contra `main` para detectar cambios manuales fuera de banda. Son dos señales distintas.

## Competencias

- **Conceptual:** describir el pipeline PR→plan→merge→apply, el rol del artefacto plan y el modelo OIDC. Explicar las divergencias actuales Terraform ↔ OpenTofu.
- **Operativa:** implementar el pipeline completo con comentario del plan en PR, environment-gated apply, y drift job programado. Instalar OpenTofu y correr el ciclo contra un módulo existente.
- **Arquitectónica:** decidir Terraform vs OpenTofu para una organización con criterios defendibles (licencia, roadmap, soporte comercial, riesgo de proveedor, features críticas).

## Ejemplos

- [`examples/01-ghactions-plan-on-pr/`](examples/01-ghactions-plan-on-pr/) — Workflow que corre `fmt` + `validate` + `plan` en cada PR y pega el plan como comentario sticky.
- [`examples/02-apply-on-merge-with-environment/`](examples/02-apply-on-merge-with-environment/) — Workflow que descarga el `plan.tfplan` artefacto y hace `apply` tras aprobación del environment.
- [`examples/03-opentofu-migration-smoke-test/`](examples/03-opentofu-migration-smoke-test/) — Script que corre el mismo módulo con `terraform` y con `tofu`, compara `plan` y state, y reporta divergencias.

## Actividades

- [`activities/01-full-cicd-tf/`](activities/01-full-cicd-tf/) — Guided-lab **dual-mode** (`MODE=local` por defecto, `MODE=live` opcional): construyes el pipeline PR→plan + merge→apply + drift schedule, con OIDC a AWS, y lo validas estructuralmente en local o end-to-end contra una cuenta real.
- [`activities/02-opentofu-eval/`](activities/02-opentofu-eval/) — Independiente: instalas `tofu`, lo pasas por un módulo existente, comparas comportamiento (plan, state, lockfile) con `terraform`, y escribes un **ADR** justificando qué recomendarías adoptar en tu organización.

## Entregables

- Pipeline funcional: PR dispara `fmt`/`validate`/`plan` con comentario sticky; merge dispara `apply` desde el artefacto plan, gated por `environment: production`; cron diario corre drift detection y notifica.
- Workflow sin ningún secret estático: todo el acceso a AWS es vía OIDC + `role-to-assume`.
- ADR Terraform vs OpenTofu con decisión, criterios ponderados y plan de migración (si aplica).

## Criterios de evaluación

| Dimensión | Nivel esperado |
|---|---|
| Pipeline | PR hace `fmt`/`validate`/`plan`; publica plan en el PR; merge hace `apply` desde el artefacto plan; apply bloqueado por environment + reviewer. |
| Seguridad | Cero `AKIA...` / `secrets.AWS_*` de larga vida; OIDC en todos los jobs cloud; `id-token: write` solo en el job que lo necesita; `permissions: {}` o `contents: read` top-level. |
| Reproducibilidad | `required_version`, lockfile versionado, versión fijada en setup-action; el `apply` consume el **mismo** `plan.tfplan` que generó el PR aprobado. |
| Drift | Job programado con `plan -refresh-only -detailed-exitcode`; notifica cuando `exitcode == 2`. |
| ADR | Decisión justificada con 4+ criterios ponderados, riesgos identificados y plan de migración concreto. |

## Recursos

Ver [`resources/links.md`](resources/links.md).
