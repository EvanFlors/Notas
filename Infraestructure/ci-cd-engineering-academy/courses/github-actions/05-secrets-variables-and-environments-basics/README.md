# gha-05 — Secretos, variables y environments (básicos)

## Identificación

- **ID:** `gha-05-secrets-variables-and-environments-basics`
- **Curso:** `github-actions`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gha-02-syntax-expressions-and-contexts` (contextos `${{ ... }}`, `env:` a tres niveles).

## Objetivo

Gestionar material sensible y configuración en GitHub Actions con criterio: diferenciar `secrets` de `vars`, elegir el **scope** correcto (repo, environment, organización), entender qué es realmente el `GITHUB_TOKEN` y aplicar **mínimo privilegio** vía `permissions:`.

## Alcance

Este módulo cubre:

- `secrets` vs `vars`: cuándo cada uno, cómo se referencian, cómo se enmascaran en logs.
- Scopes: repositorio, environment, organización — y el orden de precedencia.
- `GITHUB_TOKEN`: qué es internamente (installation token de corta vida emitido por la GitHub App del repo), su `permissions:` por defecto, por workflow y por job.
- Redacción automática en logs: qué enmascara GitHub y qué **no**.
- Environments como namespace de secretos + puerta para reglas de deployment (introducción; se profundiza en `gha-09`).
- Secretos dinámicos: introducción conceptual; OIDC completo en `gha-11`.

Lo que **no** cubre (va después):
- Required reviewers, wait timers, deployment branch rules → `gha-09`.
- OIDC a cloud providers → `gha-11`.
- Hardening completo (`pull_request_target`, pinning a SHA, script injection) → `gha-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**
  - `01-secret-usage/` — workflow mínimo que demuestra `secrets.X` vs `vars.Y` y la redacción en logs.
  - `02-permissions-minimal/` — workflow con `permissions: contents: read` por defecto y escalada selectiva por job.
- **`activities/`**
  - `01-env-vs-repo-secret/` — guided-lab, dual-mode. Diseñas la jerarquía de secretos de un repo con dos environments y lo validas localmente.
  - `02-restrict-github-token/` — guided-lab. Auditas un workflow con `permissions: write-all` y lo reescribes al modelo correcto.
- **`resources/links.md`** — documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es el `GITHUB_TOKEN`, por qué los environments existen como recurso de GitHub y no solo como texto, y por qué un secreto NO se hereda a un reusable workflow sin pasarlo explícito. |
| Operativa | Definir `secrets` y `vars` al scope correcto, referenciarlos sin filtrar nada en logs, declarar `permissions:` explícitas en todo workflow nuevo. |
| Arquitectónica | Diseñar la jerarquía secret/var para un sistema con `dev`, `staging` y `prod`, justificar cada decisión y auditar un repo con `permissions: write-all`. |

## Criterios de evaluación

- Reconocer en segundos si un workflow concede más permisos de los necesarios.
- Proponer la ubicación correcta de un dato (secret vs var, repo vs environment vs org).
- Reescribir un workflow permisivo al patrón "read-only por default + escalada por job con comentario de justificación".

## Entregable

Workflow con:
- `permissions: contents: read` a nivel top-level.
- Al menos un job con permiso escalado (`issues: write`, `pull-requests: write`, etc.) y un comentario que justifica *por qué*.
- Uso de `${{ secrets.X }}` y `${{ vars.Y }}` con nombres documentados.
- Validador local (`tests/validate.sh`) en verde.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-secret-usage/` leyendo la salida: qué aparece enmascarado y qué no.
3. Reproduce `examples/02-permissions-minimal/`.
4. Haz la actividad `01-env-vs-repo-secret/`.
5. Haz la actividad `02-restrict-github-token/` (es la evaluación operativa del módulo).
6. Responde las preguntas de la sección 12 de la lección.

## Siguiente

→ `gha-06-matrix-dependencies-outputs`: orquestar jobs dependientes y matrices. Se apoya en los `permissions:` que acabas de aprender.
