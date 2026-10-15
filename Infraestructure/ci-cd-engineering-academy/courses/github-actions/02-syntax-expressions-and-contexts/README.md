# gha-02 — Sintaxis, expresiones y contextos

## Identificación

- **ID:** `gha-02-syntax-expressions-and-contexts`
- **Curso:** `github-actions`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gha-01-model-and-first-workflow`.

## Objetivo

Dominar la **sintaxis de expresiones** `${{ ... }}`, los **contextos** (`github`, `env`, `vars`, `secrets`, `inputs`, `needs`, `job`, `runner`, `steps`, `matrix`, `strategy`) y las **funciones integradas** (`contains`, `startsWith`, `format`, `toJSON`, `fromJSON`, `hashFiles`). Al terminar, podrás **condicionar ejecución con precisión** usando `if:` en jobs y steps, usar `env:` a tres niveles, y —crítico— **evitar la vulnerabilidad de script injection** al interpolar datos no confiables.

## Alcance

- Contextos: cuáles existen, qué llevan, **cuándo** están disponibles.
- Expresiones `${{ ... }}`: operadores (`==`, `!=`, `&&`, `||`, `!`, `<`, `>`), coerción de tipos, truthiness.
- Funciones integradas: `contains`, `startsWith`, `endsWith`, `format`, `toJSON`, `fromJSON`, `hashFiles`, `join`.
- Status check functions: `success()`, `failure()`, `cancelled()`, `always()`.
- `if:` en jobs y steps — reglas de evaluación.
- `env:` a tres niveles (workflow → job → step) y precedencia.
- `continue-on-error`, `timeout-minutes`.
- **Modelo de ejecución** de expresiones: cuándo se evalúan (preparación del step vs runtime del shell).
- **Script injection**: por qué `${{ github.event.pull_request.title }}` dentro de `run:` es un *RCE pre-auth* y cómo arreglarlo.

Lo que **no** cubre (va después):
- Eventos y payloads detallados → `gha-03`.
- Actions del marketplace → `gha-04`.
- Secretos y variables en profundidad → `gha-05`.
- Matrices y `needs:` → `gha-06`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-conditionals/` — `if:` a nivel de job y step; combinación con status functions.
  - `02-contexts-dump/` — un workflow que imprime cada contexto con `toJSON()` para ver qué hay dentro.
  - `03-safe-vs-unsafe-interpolation/` — mismo workflow en versión **vulnerable** y en dos versiones **seguras** (via `env:` y via `actions/github-script`).
- **`activities/`**:
  - `01-conditional-jobs/` — guided-lab, dual-mode (`local`|`live`): construyes un workflow con 3 jobs condicionados por evento, rama y resultado del job anterior.
  - `02-fix-script-injection/` — independent: te damos un workflow vulnerable; tienes que detectarlo y arreglarlo aplicando el patrón de env var.
- **`resources/links.md`** — docs oficiales de contexts, expresiones y hardening.

## Modo `live` vs `local` en las actividades

El módulo se puede estudiar sin cuenta GitHub. Los validadores funcionan en dos modos:

| Modo | Qué hace | Requiere |
|------|----------|----------|
| `MODE=local` (default) | Verifica el YAML con `actionlint` (si está instalado) y hace checks estructurales (regex sobre el workflow). Opcionalmente ejecuta el workflow con `nektos/act`. | `actionlint` recomendado |
| `MODE=live` | Verifica además que el run exista en GitHub y haya terminado con éxito usando `gh run list`. | `gh auth status` OK + repo con el workflow pusheado |

El pipeline mental del alumno es siempre: *escribir el YAML → `actionlint` → probarlo*.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué contextos están disponibles en qué posiciones (p. ej. `secrets.*` no en `if:` de job-level sin environment). Diferenciar `success()` default implícito vs explícito. Explicar por qué `${{ ... }}` en `run:` se expande *antes* de pasar al shell, y por qué eso es RCE con input no confiable. |
| Operativa | Escribir `if:` con combinaciones de `github.event_name`, `github.ref`, `contains()`, y status functions. Usar `env:` a tres niveles con precedencia correcta. Convertir cualquier interpolación de datos de usuario en un patrón seguro (env var + quoting). |
| Arquitectónica | Diseñar una política de "nunca interpolar `github.event.*.body/title/head.ref` en `run:`", documentarla, y automatizar su detección en revisión. |

## Criterios de evaluación

- Un workflow con **lógica condicional no trivial**: al menos un job que sólo corra en `push` a `main`, al menos un step condicionado por el **resultado** del anterior, al menos un step con `continue-on-error: true` que no rompa el run.
- Un workflow **arreglado de injection** que pase el detector (ningún `${{ github.event.*.title|body|head.ref|head.label|comment.body }}` directo en `run:` ni en argumentos de `script:`), demostrando el patrón `env:` + `"$VAR"`.
- Respuesta argumentada a la pregunta de evaluación: *"Dado un workflow con `${{ github.event.pull_request.title }}` interpolado en `run:`, explica la vulnerabilidad y propone dos arreglos distintos."*

## Secuencia recomendada

1. Lee `theory/lesson.md` entera (es la parte densa del módulo).
2. Mira `examples/01-conditionals/` y `examples/02-contexts-dump/`. Si tienes repo, pusheálos y observa los logs.
3. Haz `activities/01-conditional-jobs/` en `MODE=local` primero, luego `live` si tienes repo.
4. Lee `examples/03-safe-vs-unsafe-interpolation/` **antes** de la actividad 02.
5. Haz `activities/02-fix-script-injection/`. No mires `solution/` hasta tener tu arreglo validando.
6. Responde la evaluación.

## Siguiente

→ `gha-03-events-and-triggers` (desbloquea toda la rama de eventos y payloads, incluyendo `pull_request_target`).
