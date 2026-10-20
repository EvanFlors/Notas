# gha-09 — Environments, approvals y deployment protection

## Identificación

- **ID:** `gha-09-environments-approvals-and-deployment-protection`
- **Curso:** `github-actions`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gha-05-secrets-variables-and-environments-basics`, `gha-06-matrix-dependencies-outputs`.

## Objetivo

Modelar **deployments seguros** con *environments*, *approvals*, *wait timers* y *deployment branch policies*. Al terminar deberías poder diseñar la cadena **dev → staging → prod**, justificar dónde pones gates humanos y automáticos, y explicar por qué la auditoría queda en el *deployment record* y no en un comentario del PR.

## Alcance

- `environment:` en un job: qué dispara, cuándo se evalúa, qué registra.
- Required reviewers (users y teams), wait timers, prevent self-review.
- **Deployment branch policies**: protected branches vs custom patterns.
- Secrets y variables *scoped* al environment (prod sobrescribe repo).
- Custom deployment protection rules (GitHub Apps) — overview, no implementación.
- API `deployments` y `deployment-statuses`: la "verdad" auditada.
- UI de deployments (pestaña *Environments*, badge `View deployment`).

Lo que **no** cubre (va después):
- OIDC con claim `environment:` → `gha-11`.
- Firma / attestations del artefacto a desplegar → `gha-14`.
- Required workflows aplicados a nivel org → `gha-15`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-environment-with-approval/` — `environment-production.yaml` declarativo + workflow consumidor + `apply.sh` dual-mode.
  - `02-branch-restriction/` — políticas de deployment branches (protected vs custom patterns).
- **`activities/`**:
  - `01-three-env-pipeline/` — guided-lab dual-mode: pipeline con **dev → staging → prod**, cada job con `environment:`, prod con `needs: [staging]`, sidecars YAML que declaran reviewers/wait/branch policy.
  - `02-add-manual-gate-to-prod/` — guided-lab: tomar un workflow sin gates y añadir required reviewers + wait timer + custom branch pattern a `prod`.
- **`resources/links.md`** — docs oficiales GHA + API.

## Modo `live` vs `local` en las actividades

| Modo | Qué hace | Requiere |
|------|----------|----------|
| `MODE=local` (default) | Valida el YAML del workflow con `actionlint` (si está) y la *shape* de los sidecars `environment-*.yaml`. Simula la política sin tocar GitHub. | `python3`, bash, `yq`/`python-yaml` |
| `MODE=live` | Crea los environments reales con `gh api`, inyecta reviewers/wait/branch policy, re-lee y compara. Deja los recursos para que los limpies. | `gh auth status` OK + repo propio |

El punto clave: **un environment NO vive en el YAML del workflow**. El `environment: prod` del job es solo una *referencia*. El recurso real se crea vía API (o UI) y es ahí donde viven reviewers, wait timers y branch policies. Nuestro `environment-*.yaml` es una convención del curso para versionar esa configuración como código.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el gate se evalúa **antes** de que el runner empiece el job, no durante. Diferenciar environment-level vs repo-level secrets. Describir qué queda en el deployment record. |
| Operativa | Escribir un workflow con 3 jobs encadenados (`needs:`), cada uno con `environment:`. Crear environments vía `gh api`. Añadir reviewers, wait timer y custom branch pattern. Leer el deployment record para auditar quién aprobó. |
| Arquitectónica | Diseñar la política de approvals para un equipo con **on-call**: cuántos reviewers, qué equipos, qué pasa a las 3am del sábado. Decidir si usar `wait_timer` o un canary. |

## Criterios de evaluación

- Un pipeline con **tres jobs** nombrados `dev`, `staging`, `prod`.
- Cada job declara `environment:` (`dev`, `staging`, `prod` respectivamente).
- `staging` tiene `needs: [dev]`; `prod` tiene `needs: [staging]`.
- Sidecar YAML `environment-prod.yaml` declara ≥1 reviewer, `wait_timer` definido, `deployment_branch_policy` restringe a `refs/heads/main`.
- Respuesta argumentada: *"diseña la política de approvals para un equipo con on-call"* (≥10 líneas, DECISION.md).

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-environment-with-approval/` en dry-run.
3. Haz `activities/01-three-env-pipeline/` (MODE=local primero).
4. Lee `examples/02-branch-restriction/`.
5. Haz `activities/02-add-manual-gate-to-prod/`.
6. Si tienes un repo sandbox, repite 3 y 5 en `MODE=live`.

## Siguiente

→ `gha-10-self-hosted-runners-and-arc` (si vas por el carril de operaciones) o `gha-11-oidc-and-cloud-federation` (si vas por el carril de seguridad). `gha-11` usa el claim `environment:` que aquí modelas.
