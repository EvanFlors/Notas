# gha-08 — Reusable workflows y composite actions

## Identificación

- **ID:** `gha-08-reusable-workflows-and-composite-actions`
- **Curso:** `github-actions`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gha-06-matrix-dependencies-outputs` (jobs, needs, outputs); se asume `gha-05` (secrets, permissions).

## Objetivo

Dejar de copiar y pegar YAML entre workflows. Al terminar sabrás **extraer** lógica común, **elegir** entre dos mecanismos que GitHub provee para hacerlo —**composite actions** y **reusable workflows**— y **publicar** la lógica compartida en un repo para consumirla desde otros, versionada con un tag mayor móvil (`@v1`) o un SHA inmutable.

Esta es la frontera entre "sé escribir un workflow" y "sé **operar** CI/CD como una capa de plataforma".

## Alcance

- **Composite actions**: `action.yml` con `runs.using: composite`, `inputs`, `outputs`, `steps`.
- **Reusable workflows**: `on: workflow_call` con `inputs`, `secrets`, `outputs`.
- Invocación: `uses: ./ruta/local/action`, `uses: owner/repo/.github/workflows/x.yml@v1`.
- Herencia de secretos (`secrets: inherit`) vs declaración explícita.
- Versionado: tag `v1` móvil que apunta al último SHA de la major, vs pin a SHA.
- Starter workflows a nivel organización (introducción; se profundiza en `gha-15`).
- Límites: profundidad de llamada (4 niveles), número máximo de inputs/outputs, qué contextos están disponibles.

Lo que **no** cubre (va después):
- Publicar actions propias a Marketplace y escribir JS/Docker actions → `gha-12`.
- `required workflows` / rulesets a nivel org → `gha-15`.
- OIDC pasado a reusables → `gha-11`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-composite-setup-python-plus-poetry/` — composite action que encapsula "setup Python + instalar Poetry + `poetry install`" con cache.
  - `02-reusable-deploy-workflow/` — reusable workflow con `inputs`, `secrets` y `outputs`, invocado desde un caller.
- **`activities/`**:
  - `01-extract-composite-action/` — guided-lab: tomar un workflow con pasos repetidos tres veces y extraer una composite action local.
  - `02-publish-reusable-workflow/` — independent: publicar un reusable workflow en un repo "shared" y consumirlo desde un repo "client" (dos repos simulados en `/tmp/`).
- **`resources/links.md`** — docs oficiales.

## Modo `local` en las actividades

Igual que en el curso de Git (`gh-05`), las actividades son **ejecutables sin cuenta de GitHub**. En vez de pushear a GitHub, simulamos los repos como directorios en `/tmp/` y validamos **estática y sintácticamente** los YAML (estructura, keys requeridas, referencias `uses:` con el formato correcto).

Esto permite enseñar el patrón "publicar reusable workflow" sin requerir que cada estudiante tenga una organización GitHub creada.

Para una ejecución real contra GitHub, el `README.md` de cada actividad incluye la variante `MODE=live` (opcional, requiere `gh auth`).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre composite (se expande en el job que la llama, comparte runner) y reusable workflow (define sus propios jobs, con sus runners). Enumerar los límites: profundidad 4, máx 10 inputs reusable / 10 composite, qué contextos están disponibles. Entender por qué `secrets` se pasan explícitamente y no se heredan sin `secrets: inherit`. |
| Operativa | Escribir una composite action válida con inputs, outputs y pasos de shell. Escribir un reusable workflow con `on: workflow_call`. Invocar ambos desde un caller workflow. Versionar con un tag `v1` que avanza. |
| Arquitectónica | Justificar composite vs reusable para 3 casos dados. Diseñar la convención de versionado (`@v1` móvil + pin a SHA cuando criticidad lo exige). Pensar en costo (reusable = N jobs = N runners = N minutos) vs ergonomía. |

## Criterios de evaluación

- Una composite action propia (`action.yml` con `runs.using: composite`), con al menos un `input` y un `step` que la use.
- Un reusable workflow propio (`on: workflow_call`) con `inputs`, `secrets` declarados y un `outputs` que lo propaga desde un step.
- Un workflow caller que invoque ambos.
- Documento corto (puede ser el README de tu propio repo) justificando composite vs reusable para 3 casos: "setup del lenguaje", "deploy a staging", "lint de PRs". Ver `theory/lesson.md` §12 para la rúbrica.

## Secuencia recomendada

1. Lee `theory/lesson.md` (sobre todo §2, §4 y §8 — fundamentos y trade-offs).
2. Reproduce `examples/01-composite-setup-python-plus-poetry/`.
3. Haz `activities/01-extract-composite-action/` (guided-lab).
4. Reproduce `examples/02-reusable-deploy-workflow/`.
5. Haz `activities/02-publish-reusable-workflow/` (independent).
6. Responde las 7 preguntas de evaluación de `theory/lesson.md` §12 sin consultar.

## Siguiente

→ `gha-09-environments-approvals-and-deployment-protection`. En paralelo también desbloquea `gha-12` (autoría de actions) y `gha-15` (platform patterns, que depende de este módulo para "required workflows").
