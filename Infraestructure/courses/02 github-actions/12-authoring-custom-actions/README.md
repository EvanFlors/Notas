# gha-12 — Authoring custom actions

## Identificación

- **ID:** `gha-12-authoring-custom-actions`
- **Curso:** `github-actions`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `gha-04-marketplace-actions-and-basics-of-reuse` (consumir actions, pin a SHA), `gha-08-reusable-workflows-and-composite-actions` (composite vs reusable workflow).

## Objetivo

Pasar de **consumir** actions del marketplace a **escribir, probar, versionar y publicar las tuyas**. Al terminar sabrás:

- Escribir un `action.yml` válido para los tres tipos: **composite**, **JavaScript** (Node 20) y **Docker container**.
- Usar el toolkit oficial `@actions/core` y `@actions/github` en una JS action.
- Testear una action **local y rápido** (sin depender de un run real de GitHub) y además **de integración** desde un workflow de prueba.
- Versionar responsablemente con tags `v1` móviles + release notes, y consumirla desde otro repo **pinneando a SHA**.
- Decidir con criterio **cuándo autoría de action** y **cuándo reusable workflow**.

Este módulo es la "última milla" de reutilización: por debajo de una action propia hay tres máquinas distintas (JS runtime, contenedor Docker, intérprete de composite) y entenderlas evita elegir la equivocada.

## Alcance

- `action.yml` como contrato: `name`, `description`, `inputs`, `outputs`, `runs`, `branding`.
- Tipo **composite** (`runs.using: composite` + `steps`): sin motor propio, se expande dentro del job del caller.
- Tipo **JavaScript** (`runs.using: node20` + `main:`): ejecuta `dist/index.js` directamente en el runner. Rápido, portable (Linux/macOS/Windows).
- Tipo **Docker container** (`runs.using: docker` + `image:` o `Dockerfile`): aislamiento máximo, **solo runners Linux**.
- Toolkit:
  - `@actions/core` — `getInput`, `setOutput`, `info`, `warning`, `setFailed`, `exportVariable`, `addPath`, `summary`.
  - `@actions/github` — cliente REST/GraphQL autenticado con el `GITHUB_TOKEN` y el contexto `github.context`.
- Compilación con `@vercel/ncc` a `dist/index.js` (bundle único) — se explica el porqué.
- Testing:
  - **Local** del action: ejecutar `node dist/index.js` con `INPUT_*` como env vars (así es como el runner invoca la action).
  - **Integración** en un workflow de prueba (`.github/workflows/test.yml`) con `uses: ./`.
- Versionado: `v1` tag móvil que avanza con cada release de la mayor + release notes legibles.
- Publicación al Marketplace (requisitos: repo público, `action.yml` en raíz, metadata completa).
- Decisión: **action propia vs reusable workflow vs composite local**.

Lo que **no** cubre (va después):
- Supply chain (SBOM, attestations, firma con cosign) → `gha-14`.
- Políticas a nivel org (required workflows, pin obligatorio) → `gha-15`.
- Hardening específico de actions (anti script injection en inputs) → `gha-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-composite-action-structure/` — anatomía mínima de una composite action con inputs/outputs.
  - `02-js-action-with-core-and-github/` — JS action que lee un input, llama al toolkit y setea un output.
  - `03-docker-action/` — Docker action con `Dockerfile` + `entrypoint.sh`.
- **`activities/`**:
  - `01-write-composite-action/` — **guided-lab**: construir una composite action que valide el formato de una variable.
  - `02-write-js-action/` — **mini-project (independent)**: JS action completa con `@actions/core`, test local y workflow de integración.
  - `03-publish-and-pin/` — **guided-lab**: "publicar" (en un repo simulado) + consumirla desde otro repo pinneando a SHA.
- **`resources/links.md`** — docs oficiales del toolkit y de `action.yml`.

## Modo `local` en las actividades

Igual que `gha-08` y `gh-05`, las actividades aquí **no requieren una cuenta de GitHub**. Las actions se construyen y validan con las mismas herramientas que usa el runner (Node 20, Docker, Bash), pero el ciclo "publicar → consumir desde otro repo" se simula con dos repos `--bare` en `/tmp/`.

Si `node` o `docker` no están instalados, los validadores afectados se **saltan limpiamente** con un mensaje que indica cómo instalarlos.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar las diferencias de runtime: composite se expande inline en el job; JS corre `node` directo en el runner (rápido, cross-OS); Docker corre un contenedor (solo Linux, cold start lento). Enumerar qué contextos tiene cada tipo (`inputs` via `INPUT_*`, `GITHUB_*`, `RUNNER_*`). Justificar `dist/` commiteado en JS actions. |
| Operativa | Escribir un `action.yml` válido de cada tipo. Usar `@actions/core` para I/O y `@actions/github` para hablar con la API. Testear local con `INPUT_*` env vars. Taggear `v1.0.0`, mover `v1`. |
| Arquitectónica | Decidir composite vs JS vs Docker vs reusable workflow para un caso dado. Diseñar la estrategia de versionado para una action consumida por N repos (quién decide subir mayor, cuándo). Pensar en la supply chain: tu action pasa a ser dependencia de todos los consumidores. |

## Criterios de evaluación

- Al menos **una JS action propia** con `action.yml`, `src/index.js` que usa `@actions/core`, `dist/index.js` compilado con `ncc`, workflow de prueba en el mismo repo, y un tag `v1.0.0` + `v1` móvil.
- Una composite action adicional (puede ser la del `activities/01`) usada desde un workflow.
- Repo consumidor que invoca la action vía `uses: owner/repo@<SHA>` (SHA, no tag).
- Documento corto (puede ir en el README de tu action) justificando por qué elegiste ese tipo y qué estrategia de versionado sigues.

## Secuencia recomendada

1. Lee `theory/lesson.md` completa — en especial §2 (anatomía), §4 (tipos), §7 (toolkit) y §9 (versionado).
2. Reproduce `examples/01-composite-action-structure/`.
3. Haz `activities/01-write-composite-action/` (guided-lab).
4. Reproduce `examples/02-js-action-with-core-and-github/`.
5. Haz `activities/02-write-js-action/` (mini-project, independent).
6. Reproduce `examples/03-docker-action/`.
7. Haz `activities/03-publish-and-pin/` (guided-lab).
8. Responde las preguntas de evaluación de `theory/lesson.md` §12 sin consultar.

## Siguiente

→ `gha-13-security-hardening` (incluye el *script injection* en inputs de actions ajenas).
En paralelo: `gha-14` (supply chain) usará tu action para firmarla y emitir attestations.
