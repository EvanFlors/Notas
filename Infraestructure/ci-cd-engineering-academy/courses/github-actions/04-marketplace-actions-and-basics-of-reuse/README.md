# gha-04 — Marketplace actions y bases de reutilización

## Identificación

- **ID:** `gha-04-marketplace-actions-and-basics-of-reuse`
- **Curso:** `github-actions`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gha-01-model-and-first-workflow`.

## Objetivo

Usar **actions del Marketplace** de forma segura. Al terminar debes poder:

1. Diferenciar los **tres tipos** de actions (JavaScript, Docker container, composite).
2. Entender la sintaxis `owner/repo@ref` y por qué el `ref` puede ser **tag**, **branch** o **SHA**.
3. Justificar por qué **pinnear a SHA de 40 caracteres** con comentario de versión es la práctica correcta para dependencias de terceros.
4. **Auditar** un workflow ajeno y detectar `uses:` que no están pinneados a SHA.
5. Describir el rol de **Dependabot** manteniendo esos pins actualizados.

## Alcance

- Tipos de actions: *JavaScript*, *Docker container*, *composite*.
- Referenciar actions: `owner/repo@<ref>`; semver tags (`@v4`), tags exactos (`@v4.2.2`), branches (`@main`) y **SHAs** (`@11bd71901bbe5b1630ceea73d27597364c9af683`).
- **Mutabilidad de tags en Git** y por qué los branches *jamás* son referencia segura para una action externa.
- Catálogo oficial mínimo: `actions/checkout`, `actions/setup-python`, `actions/setup-node`, `actions/upload-artifact`, `actions/cache`.
- Taxonomía de confianza: *first-party GitHub* vs *trusted vendors* (HashiCorp, Docker, AWS, Google, Azure) vs *terceros desconocidos*.
- **Dependabot** para `package-ecosystem: github-actions` (`.github/dependabot.yml`).
- Fundamento: cómo verificar un pin con `gh api repos/<owner>/<repo>/git/refs/tags/<tag>` y el patrón "SHA + comentario `# v<SEMVER>`".

Lo que **no** cubre (va después):
- **Autoría** de una action JS / Docker / composite propia → `gha-12`.
- **Reusable workflows** (`workflow_call`) y organización de composites → `gha-08`.
- Hardening avanzado del `GITHUB_TOKEN` y OIDC → `gha-05`, `gha-11`.
- SBOM, firma, attestations SLSA → `gha-14`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-setup-python-matrix/` — matriz 3.11/3.12/3.13 usando `actions/setup-python` pinneada a SHA.
  - `02-pin-to-sha/` — mismo workflow en 3 formas (`@main`, `@v4`, `@<SHA>`); explica diferencias y riesgos.
- **`activities/`**:
  - `01-use-three-marketplace-actions/` — *guided-lab*: elige 3 actions del Marketplace, úsalas y pinnealas todas a SHA con comentario de versión.
  - `02-audit-a-workflow-for-unpinned-deps/` — *independent*: audita un workflow lleno de `@v4`, `@main` y `@master`, repórtalo y arréglalo.
- **`resources/links.md`** — docs oficiales de GitHub, Dependabot y herramientas de audit.

## Modos de ejecución

Este módulo **no requiere GitHub real** para ninguna de sus actividades: todo se valida sobre archivos YAML locales con un linter + regex. Puedes correr el pipeline real en una fase opcional ("extensión") si tienes `act` o un repo descartable; no es obligatorio.

| Herramienta | Para qué | Instalación |
|-------------|----------|-------------|
| `actionlint` (opcional) | Linter oficial de workflows GHA | <https://github.com/rhysd/actionlint> |
| `python3` + `pyyaml` | Validadores de las actividades | `pip install pyyaml` |
| `act` (muy opcional) | Correr workflows localmente | <https://github.com/nektos/act> |

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar JS vs Docker vs composite. Explicar por qué un tag Git es *mutable* y qué significa pinnear a SHA. Diferenciar first-party, trusted vendor y tercero desconocido. |
| Operativa | Resolver tag → SHA con `gh api` o `git ls-remote`. Reescribir un workflow para que todas sus `uses:` queden en formato `owner/repo@<SHA>  # v<SEMVER>`. Configurar `dependabot.yml` para `github-actions`. |
| Arquitectónica | Decidir cuándo aceptar `@v4` (actions oficiales dentro de un repo privado de bajo blast radius) vs cuándo exigir SHA (producción, repo público, action de tercero). Diseñar la política de pinning para una organización. |

## Criterios de evaluación

- Un workflow (de la actividad 01) con **≥ 3 actions distintas**, cada una pinneada a SHA de 40 chars y con comentario `# v<SEMVER>`.
- Un workflow (de la actividad 02) completamente *desintoxicado*: ninguna `uses:` queda con `@main`, `@master` ni `@v<N>` sin SHA.
- Respuesta argumentada a la pregunta: "Dame un ejemplo concreto en el que un tag reescrito te comprometió el pipeline" (narrativa realista, no abstracta).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-setup-python-matrix/` leyendo el YAML línea por línea.
3. Reproduce `examples/02-pin-to-sha/` y responde las preguntas del final del README del ejemplo.
4. Haz `activities/01-use-three-marketplace-actions/` (guided).
5. Haz `activities/02-audit-a-workflow-for-unpinned-deps/` (independent).
6. Responde las preguntas de evaluación de `theory/lesson.md` sin consultar.

## Siguiente

→ `gha-05-secrets-variables-and-environments-basics` (base para OIDC y entornos).
