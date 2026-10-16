# helm-09 — Testing: lint, unittest y chart-testing

## Identificación

- **ID:** `helm-09-testing-lint-unittest-and-chart-testing`
- **Curso:** `helm`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `helm-04-templating-deep`, `helm-06-dependencies-and-umbrella-charts`

## Objetivo

Diseñar e implementar una **pipeline de validación por capas** que atrape los bugs de un chart *antes* de distribuirlo: `helm lint` (sintaxis y estilo), `helm template --debug` (render diferencial en PR), **`helm-unittest`** (asserts sobre manifests renderizados, sin cluster), **`chart-testing (ct)`** (lint + install + `helm test` sobre `kind` en una **matriz de versiones de Kubernetes**), y el patrón de **snapshot testing** para templates estables. Integrar todo en **GitHub Actions**.

Al terminar deberías poder, sin consultar docs:

- Explicar por qué cada capa (lint → template → unittest → install) atrapa una clase distinta de bugs y por qué **ninguna sola basta**.
- Escribir tests de `helm-unittest` que cubran los edge cases típicos de values: default, override completo, **lista vacía**, **nil**, flag booleano.
- Decidir qué versiones de Kubernetes incluir en la matriz de `ct install` y defender la elección.
- Añadir snapshot tests y saber cuándo actualizarlos (y cuándo *no*).
- Montar el workflow GHA completo que corra las cuatro capas en PR.

## Alcance

Este módulo cubre:

- **`helm lint`** — estilo, campos obligatorios, errores sintácticos del chart.
- **`helm template --debug`** — "dry render" útil para generar el *diff* de manifests en un PR.
- **`helm-unittest`** — plugin que renderiza templates y aplica asserts sin tocar un cluster. Cubre la lógica de `if/else`, `range`, `default`, `required` y edge cases de values.
- **`chart-testing` (`ct`)** — herramienta mantenida por la comunidad Kubernetes que corre `lint + install + helm test` detectando qué charts cambiaron y probándolos en una **matriz de versiones de K8s** sobre `kind`.
- **Snapshot testing** — pattern para fijar la salida renderizada esperada y detectar regresiones silenciosas.
- Integración en **GitHub Actions**: `helm/chart-testing-action`, `helm/kind-action`, matriz de versiones.

Lo que **no** cubre (vive en otros módulos):

- Publicación y firma del chart → `helm-08`.
- Hooks y `helm test` como mecanismo de release (no de CI) → `helm-07`.
- Integración con Argo CD / Flux post-render → `helm-10`.

## Materiales

- **`theory/lesson.md`** — 12 secciones (≈ 2 h). Modelo mental de "capas", internals de `helm-unittest`, cómo `ct` detecta charts cambiados, matriz de versiones.
- **`examples/`**:
  - `01-ct-workflow/` — workflow GHA de referencia usando `chart-testing-action` + `kind-action` con matriz.
  - `02-helm-unittest-cases/` — chart demo con una batería de tests `helm-unittest` cubriendo default/override/null/empty/flag.
  - `03-snapshot-testing/` — patrón de snapshot con `helm-unittest`.
- **`activities/`**:
  - `01-add-full-test-pipeline/` (**guided-lab**) — montar lint + template + unittest + `ct install` sobre `kind` en GHA.
  - `02-cover-edge-cases-with-unittest/` (**independent**) — escribir tests que cubran 5 edge cases concretos.
- **`resources/links.md`** — docs oficiales, repos de referencia.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar la pirámide de testing para charts y qué clase de bug atrapa cada capa. Explicar por qué un chart "pasa `helm lint`" y aun así puede renderizar YAML inválido. |
| Operativa | Escribir un `unittest`-suite completo para un chart; añadir `.github/workflows/ci-chart.yaml` con `ct install` en matriz; depurar un fallo de `ct install` leyendo logs de `kind`. |
| Arquitectónica | Diseñar la **matriz de versiones de Kubernetes** a soportar: política de soporte (p. ej. n, n-1, n-2), coste de CI, calendario upstream de `kind`. |

## Entregables

- Pipeline GHA (`.github/workflows/ci-chart.yaml`) que ejecuta las **4 capas**: `helm lint`, `helm template --debug`, `helm unittest`, `ct install` sobre una matriz de 2+ versiones de K8s.
- Chart con **`tests/`** de `helm-unittest` cubriendo: valores por defecto, override completo, lista vacía, `nil`, flag booleano `true/false`.

## Criterios de evaluación

- Lección leída y preguntas de §12 respondidas.
- Actividad 01: workflow GHA presente, 4 capas conectadas, matriz de versiones justificada en el `README.md` de la actividad; `tests/validate.sh` estructural pasa.
- Actividad 02: 5 edge cases cubiertos con asserts concretos (no solo `isKind`); `helm unittest` corre verde si el plugin está instalado.
- Saber contestar: *"¿Qué bug atrapa `ct install` que `helm-unittest` nunca atrapará?"*

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Revisa `examples/02-helm-unittest-cases/` para fijar el patrón de asserts.
3. Revisa `examples/01-ct-workflow/` — compara con un workflow que ya conozcas.
4. Revisa `examples/03-snapshot-testing/`.
5. Haz la actividad `01-add-full-test-pipeline/`.
6. Haz la actividad `02-cover-edge-cases-with-unittest/`.
7. Responde las preguntas de §12.

## Siguiente

→ `helm-10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary`.
