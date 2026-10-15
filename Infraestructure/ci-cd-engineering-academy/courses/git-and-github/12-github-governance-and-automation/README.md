# gh-12 — GitHub governance and automation

## Identificación

- **ID:** `gh-12-github-governance-and-automation`
- **Curso:** `git-and-github`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gh-07-collaboration-prs-and-review`, `gh-08-workflows-trunk-vs-gitflow`.

## Objetivo

Aplicar **gobernanza** sobre GitHub a tres niveles (repositorio, organización, empresa) para que el workflow definido en `gh-07`/`gh-08` sea **enforzado** por la plataforma, no por buena voluntad. Al terminar, deberías poder diseñar y configurar: un **Ruleset** sobre `main`, un **CODEOWNERS** con reviewers obligatorios, un **environment** con approval y wait timer, y emitir el **token correcto** (PAT fine-grained, GitHub App installation token, OIDC federation) para cada caso de uso.

## Alcance

- Organizations, teams, roles base (owner, member, outside collaborator) y permisos por repo/team.
- **Rulesets** (reemplazo moderno de *classic branch protection*): required status checks, required deployments, required signatures, required linear history, merge queues, bypass actors.
- **Environments** con required reviewers, wait timers, deployment branch policies y secrets de environment.
- **Autenticación**: PAT classic vs fine-grained PAT vs GitHub App installation token vs OIDC-to-cloud.
- **Webhooks** y suscripción a eventos.
- **GitHub API** (REST + GraphQL) y `gh` CLI avanzada.
- **ADR**: justificar la elección de identidad/token para una automatización.

Lo que **no** cubre (va en `gh-13`):
- Firma de commits y verified status, Dependabot, CodeQL, secret scanning, SBOM, SLSA attestations.
- OIDC extremo-a-extremo con trust policy real aplicada en AWS/GCP/Azure.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-ruleset-main-branch/` — definición JSON de un ruleset para `main` + comandos `gh api` para aplicarlo.
  - `02-environment-with-approval/` — descripción YAML de un environment `production` con required reviewers y wait timer, aplicable vía `gh api`.
  - `03-oidc-to-aws-cloud/` — trust policy IAM de ejemplo (cuenta y role **placeholder**) y workflow Actions con `permissions: id-token: write`.
- **`activities/`**:
  - `01-apply-rulesets/` — guided-lab (modo `local` por default; `live` opcional con `gh`).
  - `02-codeowners-plus-required-reviewers/` — guided-lab (modo `local` por default; `live` opcional).
  - `03-github-app-vs-pat/` — **independent**: ADR comparando identidades para una automatización.
- **`resources/links.md`** — documentación oficial.

## Dos modos de validación

Las actividades 01 y 02 soportan dos modos (controlados por la variable `MODE`):

| Modo | Qué hace | Requisitos |
|------|----------|------------|
| `local` (default) | Valida que los archivos YAML/JSON de ruleset / CODEOWNERS / env están presentes, son sintácticamente válidos y cumplen los campos mínimos exigidos. **Sin GitHub**. | `python3`, `yq` opcional. |
| `live` | Idem + consulta la API de GitHub con `gh` para comprobar que la configuración está realmente aplicada al repo. | `gh auth login` como usuario con permisos de admin sobre un repo propio. Variables `GH_OWNER`, `GH_REPO`. |

El validador defaultea a `local` para ser portable. **Documenta los costos**: `live` requiere cuenta en GitHub (gratis). No se gastan dólares en este módulo.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar classic branch protection vs Rulesets. Explicar por qué GitHub Apps emiten installation tokens de corta vida. Describir el flujo OIDC entre Actions y una cloud (sin claim de "mágico"). |
| Operativa | Escribir y aplicar un ruleset JSON vía `gh api`. Configurar CODEOWNERS + required reviewers. Crear environment con approval y wait timer. Elegir PAT fine-grained vs GitHub App para un script dado. |
| Arquitectónica | Diseñar política coherente con `gh-08` (trunk-based vs release branches). Justificar bypass actors. Decidir cuándo exigir `required signatures`. Trazar un ADR de identidad. |

## Entregables

- Repo (local o en GitHub) con: un **Ruleset JSON** aplicable sobre `main`, **CODEOWNERS** válido, descripción de **environment** `production` con approvers, y un **PR template**.
- Un **ADR** (actividad 03) justificando la elección entre PAT fine-grained, GitHub App o OIDC para una automatización dada.

## Criterios de evaluación

- Rulesets JSON válido y aplicable (ver `tests/validate.sh` modo `local`).
- CODEOWNERS cubre los paths críticos; validado por `gh api` en modo `live` o por parser local en modo `local`.
- Environment con `required_reviewers` + `wait_timer` configurados.
- ADR responde: *por qué este token, por qué no los otros, qué daño causaría una fuga*.
- Respuesta argumentada a las preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entera.
2. Reproduce `examples/01-ruleset-main-branch/` (dry-run con `--dry-run` o `jq .` sobre el JSON).
3. Haz `activities/01-apply-rulesets/` en modo `local`. Si tienes repo propio: repite en `live`.
4. Reproduce `examples/02-environment-with-approval/`.
5. Haz `activities/02-codeowners-plus-required-reviewers/`.
6. Reproduce `examples/03-oidc-to-aws-cloud/` (solo lectura — no se aplica a cloud real aquí).
7. Haz `activities/03-github-app-vs-pat/` (ADR, independiente).
8. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `gh-13-github-security-and-supply-chain`.
