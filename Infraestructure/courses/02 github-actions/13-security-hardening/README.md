# gha-13 — Security hardening for GitHub Actions

## Identificación

- **ID:** `gha-13-security-hardening`
- **Curso:** `github-actions`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gha-04-marketplace-actions-and-basics-of-reuse`, `gha-05-secrets-variables-and-environments-basics`, `gha-11-oidc-and-cloud-federation`.

## Objetivo

Endurecer workflows de GitHub Actions siguiendo la **guía oficial de security hardening** y las lecciones de incidentes públicos reales (`tj-actions/changed-files` 2025, Codecov 2021, Dependabot token leak 2023). Al terminar deberías poder **auditar un workflow ajeno** detectando con precisión las fallas comunes y **endurecer un workflow propio** aplicando el patrón recomendado: permisos mínimos, pinning por SHA, interpolación segura, uso correcto de `pull_request_target` y defensa en profundidad.

## Alcance

- **`permissions:`** por defecto a `contents: read` (o `{}`) a nivel top-level, con **escalada mínima por job**.
- **`pull_request_target` seguro**: cuándo usarlo, cómo evitar el checkout del `head.sha` del PR, patrón "aislar código no confiable".
- **Evitar interpolación de `${{ ... }}` no sanitizada** en bloques `run:` — **script injection** (vulnerabilidad consistentemente en el top-5 de los security advisories de GitHub).
- **Pinning por SHA** de todas las actions (incluidas las oficiales) + comentario con la versión legible.
- **Dependabot para actions** (`.github/dependabot.yml` con `package-ecosystem: github-actions`) para mantener los pins actualizados.
- **Scope de secrets**: por qué los secrets no se exponen a workflows de forks por default; `pull_request_target` como superficie de ataque.
- **Approval de workflows** en PRs externos (`Settings → Actions → Fork pull request workflows from outside collaborators`).
- **StepSecurity Harden-Runner** como **defensa en profundidad** egress-control runtime.
- **Anatomía de incidentes públicos** y qué defensa de este módulo los habría evitado.

## No cubre

- SBOM y attestations SLSA → `gha-14`.
- Políticas a nivel organización (required workflows, rulesets) → `gha-15`.
- Hardening de runners **self-hosted** (networking, aislamiento K8s, ARC) → `gha-10`.
- OIDC a cloud providers end-to-end → `gha-11` (prerrequisito).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**
  - `01-least-privilege-token/` — workflow con `permissions: {}` top-level + escalada por job.
  - `02-safe-pull-request-target/` — patrón seguro + anti-patrón **comentado** con explicación.
  - `03-pin-all-actions-with-dependabot/` — workflow pinneado a SHA + `dependabot.yml` para actualizarlos.
- **`activities/`**
  - `01-harden-an-existing-workflow/` — **independiente**: workflow realista con ~5 fallas; alumno produce versión endurecida + ADR.
  - `02-detect-script-injection/` — **guided-lab**: localizar y corregir una interpolación insegura en `run:`.
- **`resources/links.md`** — docs oficiales + incidentes reales documentados.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `pull_request_target` concede secrets al workflow pero `pull_request` no, y cuál es la vulnerabilidad del patrón mal usado. Describir qué significa pinnear a SHA vs tag y por qué los tags son mutables. Enunciar la diferencia entre interpolación `${{ }}` y variable de entorno en `run:`. |
| Operativa | Convertir un workflow con `permissions: write-all` a un modelo de mínimo privilegio con escalada por job. Pinnear todas las actions a SHA con comentario. Configurar Dependabot para GitHub Actions. Reescribir un `run:` vulnerable a inyección usando `env:` y `"$VAR"`. |
| Arquitectónica | Diseñar la política de seguridad obligatoria de workflows a nivel repo/org: qué está prohibido, qué requiere approval, qué requiere SHA pinning. Priorizar hallazgos de una auditoría en P0/P1/P2 con justificación. |

## Criterios de evaluación

- **Entregable 1**: workflow endurecido que pasa el validator de `activities/01-harden-an-existing-workflow/` sin trampas (todas las actions pinneadas a SHA, `permissions:` explícito, cero interpolación insegura).
- **Entregable 2**: **ADR** (Architecture Decision Record) justificando cada cambio aplicado al workflow: qué anti-patrón había, qué incidente del mundo real materializa ese riesgo, qué defensa se eligió y por qué.
- Capacidad de resolver sin pistas la actividad 02 (script injection) y explicar por qué el fix funciona (orden de evaluación de `${{ }}` vs shell).

## Secuencia recomendada

1. Lee `theory/lesson.md` secciones 1–6.
2. Reproduce `examples/01-least-privilege-token/` y `examples/03-pin-all-actions-with-dependabot/` en un repo scratch.
3. Haz `activities/02-detect-script-injection/` (guided-lab corto, prepara el ojo).
4. Lee las secciones 7–9 (profesional, trade-offs, errores) y en particular la 10 (anatomía de incidentes).
5. Haz `activities/01-harden-an-existing-workflow/` (independiente, 90 min). Escribe el ADR a conciencia.
6. Lee secciones 11–12 (ejercicios + evaluación) y responde sin consultar.

## Siguiente

- `gha-14-supply-chain-sbom-attestations-signing` — construye encima: ya tienes workflows endurecidos, ahora emites evidencia verificable de qué construyeron.
- `gha-15-platform-patterns-and-cost-governance` — operacionaliza este módulo a nivel organización vía required workflows y rulesets.
