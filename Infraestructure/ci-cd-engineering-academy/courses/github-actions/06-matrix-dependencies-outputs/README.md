# gha-06 — Matrices, dependencias y outputs entre jobs

## Identificación

- **ID:** `gha-06-matrix-dependencies-outputs`
- **Curso:** `github-actions`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gha-02` (sintaxis, expresiones y contextos), `gha-05` (secretos, variables y `GITHUB_TOKEN`).

## Objetivo

Orquestar un workflow con varios **jobs** que forman un DAG: una fase de `test` **matricial** (varias versiones de Python × varios OS), una fase de `build` única que **depende** de los tests, y una fase de `deploy` protegida con **concurrency** para evitar carreras hacia producción. En paralelo, aprender a **pasar valores** de un job a otro vía `outputs` + `$GITHUB_OUTPUT` y a **cerrar el run con un resumen** vía `$GITHUB_STEP_SUMMARY`.

## Alcance

Este módulo cubre:

- `strategy.matrix` con dimensiones múltiples; `include` (añadir combinaciones) y `exclude` (quitarlas).
- `fail-fast` (abortar hermanas al primer fallo) y `max-parallel` (techo de concurrencia por matriz).
- `needs:` — forma del grafo (serie, fan-out, fan-in, aggregator).
- `outputs` de un job vía `echo "key=value" >> "$GITHUB_OUTPUT"` + `jobs.<id>.outputs.<key>`; consumo con `${{ needs.<id>.outputs.<key> }}`.
- `concurrency` (grupos nombrados) y `cancel-in-progress`.
- Job summary (`$GITHUB_STEP_SUMMARY`) como artefacto humano del run.

Lo que **no** cubre (se verá después):

- Caché y artefactos entre jobs → `gha-07`.
- Reusable workflows / composite actions → `gha-08`.
- Environments con approvals (gates humanos) → `gha-09`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (modelo mental, internals, trade-offs, errores frecuentes).
- **`examples/`**:
  - `01-matrix-python-os/` — matriz 2D (python × os) con `include`/`exclude`.
  - `02-needs-and-outputs/` — job A computa un `version_tag`, job B lo consume.
  - `03-concurrency-deploy-lock/` — lock por grupo `deploy-prod`; segundo push espera en cola o cancela.
- **`activities/`**:
  - `01-matrix-with-include-exclude/` — guided-lab, dual-mode (`local` valida YAML; `live` ejecuta en GitHub).
  - `02-fan-out-fan-in/` — independent, mini-pipeline con N jobs de build en paralelo + aggregator que resume en `$GITHUB_STEP_SUMMARY`.
- **`resources/links.md`** — docs oficiales verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `GITHUB_OUTPUT` reemplazó `::set-output` (riesgo de script injection). Describir qué hace `concurrency` cuando un segundo run encola. Diferenciar `fail-fast: true/false` y cuándo elegir cada uno. |
| Operativa | Escribir una matriz 3D con `include`/`exclude`. Propagar un valor computado de un job a sus dependientes. Prevenir dos deploys concurrentes a prod. Emitir un resumen Markdown en el summary del run. |
| Arquitectónica | Diseñar un DAG test → build → deploy con fan-out/fan-in. Decidir `cancel-in-progress: true` vs `false` según riesgo del dominio (CI vs CD). |

## Criterios de evaluación

- Workflow con fase `test` matricial, fase `build` única y fase `deploy` protegida con `concurrency`.
- Al menos un job que **emite** un output y al menos otro job que **lo consume** vía `needs.<id>.outputs.<key>`.
- `permissions:` definidos explícitamente a nivel workflow (default `contents: read`), no heredados.
- Al menos un `include` **y** un `exclude` en la matriz, justificados.
- Capacidad de responder la pregunta de evaluación: *"Si dos pushes a `main` encolan deploys y `concurrency` está activa con `cancel-in-progress: true`, ¿qué pasa con cada run?"*.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada).
2. Reproduce `examples/01-matrix-python-os/` (basta leer el YAML; opcionalmente ejecútalo).
3. Reproduce `examples/02-needs-and-outputs/` y verifica mentalmente el flujo del valor.
4. Lee `examples/03-concurrency-deploy-lock/` prestando atención a los dos escenarios documentados.
5. Haz la actividad `activities/01-matrix-with-include-exclude/` (guided-lab).
6. Haz la actividad `activities/02-fan-out-fan-in/` (independent) — valida la competencia real.
7. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `gha-07-caching-and-artifacts`: acelerar jobs con caché y mover archivos entre jobs/runs con artefactos.
