# gl-03 — Variables y secretos: protected, masked y jerarquía

## Identificación

- **ID:** `gl-03-variables-and-secrets-protected-and-masked`
- **Curso:** `gitlab-cicd`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gl-02-gitlab-ci-yml-pipelines-runners`.

## Objetivo

Dominar el modelo de **variables y secretos** de GitLab CI/CD: entender la jerarquía Instance → Group → Project → Environment → Pipeline, el uso correcto de los flags `protected` y `masked`, la diferencia entre variables tipo `variable` y tipo `file`, y la vía moderna para evitar credenciales de larga vida: **ID Tokens (OIDC)** federados con secret managers externos (HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager).

Al terminar deberías poder diseñar un esquema de variables con **mínimo privilegio** (prod protegido, dev abierto) y escribir un `.gitlab-ci.yml` que obtenga secretos desde Vault vía OIDC, sin un solo token de larga vida en la configuración del proyecto.

## Alcance

Este módulo cubre:

- **Jerarquía de scopes**: Instance → Group → Project → Environment → Pipeline. Precedencia (el nivel más específico gana) y cuándo usar cada uno.
- **Tipos de variable**: `variable` (text, inyectada como env var) vs `file` (contenido escrito a disco, path expuesto en la env var).
- **Flags** por variable:
  - `protected` — solo pipelines corriendo en **refs protegidas** (branches/tags protegidos) pueden leerla.
  - `masked` — el valor se filtra de los logs del job (requisitos: base64-ish, 8+ chars, sin saltos de línea).
  - `expanded` / `raw` — si GitLab expande `$VAR` dentro del valor o lo deja literal.
- **ID Tokens (JWT)**: equivalente a OIDC token de GitHub Actions. Emitidos por GitLab por job, firmados por GitLab. Permiten federar con AWS/GCP/Azure/Vault **sin keys**.
- **`secrets:` key**: cómo declarar en un job que un valor vendrá de Vault/AWS SM/GCP SM/Azure KV, enlazando el ID Token con el motor de secretos.
- **Riesgos de injection**: la sintaxis es `$VAR` (sin `${{ }}` como GHA, pero el riesgo es análogo si se interpola input no confiable en `script:`).
- **Comparación GHA**: `secrets.FOO` ≈ variable project-scoped masked; `id-token: write` ≈ `id_tokens:` block en el job.

Lo que **no** cubre (se verá después):

- Runners propios y la configuración de OIDC a nivel runner → `gl-06`.
- Scanners de **Secret Detection** (los que detectan secretos filtrados en el repo) → `gl-08`.
- Compliance frameworks que fuerzan políticas de variables a nivel grupo → `gl-09`.

Este módulo es **mayoritariamente conceptual + ejercicios de configuración**. **No** se despliega infraestructura real: todas las actividades producen archivos (`.gitlab-ci.yml`, `variables.yml`, `README-INTENT.md`) que un validador estructural comprueba localmente. **Nunca** se usan secretos reales — solo valores dummy (`dummy-token-xxx`, `vault.example.com`).

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — tres ejemplos demostrativos:
  - `01-group-vs-project-var/` — misma variable `DEPLOY_ENV` definida en Group y Project; muestra la precedencia y cuándo conviene cada uno.
  - `02-protected-and-masked/` — matriz de combinaciones `protected`×`masked` con escenario de fuga y mitigación.
  - `03-secrets-from-vault-with-idtoken/` — anatomía de un job con `id_tokens:` + `secrets:` leyendo de Vault por OIDC.
- **`activities/`** — dos actividades:
  - `01-least-privilege-variables/` (guided-lab) — escribir `variables.yml` + `.gitlab-ci.yml` con la jerarquía dev/stg/prod aplicando `protected`/`masked` correctamente.
  - `02-oidc-to-vault/` (independent) — escribir un `.gitlab-ci.yml` con `id_tokens:` + `secrets:` que lee un secreto de Vault vía OIDC, sin variables de larga vida.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la precedencia entre scopes; qué diferencia hay entre `protected` y `masked`; por qué un ID Token elimina credenciales de larga vida. |
| Operativa | Escribir un `variables.yml` que documente qué variable vive en qué scope con qué flags; redactar un job con `id_tokens:` + `secrets:` correcto. |
| Auditoría | Dado un `variables.yml` con fugas, identificar qué variable debería estar `protected`/`masked` y proponer refactor. |

## Criterios de evaluación

- Dado un escenario con 5 variables (API URLs, tokens, flags de feature), decidir el scope correcto y los flags por cada una.
- Leer un `.gitlab-ci.yml` con `id_tokens:` + `secrets:` y explicar qué `aud` claim se emite, qué rol de Vault se asume y qué secreto se obtiene.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- `variables.yml` + `.gitlab-ci.yml` con jerarquía dev/stg/prod y flags correctos (sale de la actividad `01`).
- `.gitlab-ci.yml` con `id_tokens:` + `secrets:` federado a Vault + `README-INTENT.md` justificando la decisión (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos YAML. No se requiere instancia de GitLab, Vault ni cuentas cloud. Si en una fase posterior decides provisionar lo diseñado:

- **GitLab SaaS**: variables/secretos/ID Tokens son gratis en todos los planes.
- **HashiCorp Vault**: Vault OSS es gratis; Vault Enterprise/HCP tienen pricing propio.
- Los **minutos de runner** consumidos por los jobs que llaman a Vault sí cuentan.

## Siguiente módulo

→ `gl-04-rules-workflow-needs-dag-parallel-matrix` — controlar cuándo corren pipelines/jobs y modelar DAGs; usarás las variables de este módulo en condiciones de `rules:`.
