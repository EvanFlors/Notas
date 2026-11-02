# sys-16 — Loops e iteración

## Identificación

- **ID:** `sys-16-loops-and-iteration`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-15-arithmetic-tests-and-conditionals`

## Objetivo

Recorrer secuencias de datos (listas, archivos, salidas de comandos, APIs) de manera **correcta** (sin romperse ante nombres raros) y **eficiente** (sin lanzar un proceso por iteración si no hace falta). Al terminar, deberías saber cuándo usar `for`, cuándo `while read`, y por qué `for f in $(ls)` es casi siempre un bug.

## Alcance

Este módulo cubre:

- `for i in LISTA`, `for ((i=0;i<n;i++))`, `while CONDICION`, `until CONDICION`.
- El patrón canónico `while IFS= read -r line`.
- Por qué `for f in $(ls)` está mal: word splitting, globbing, pérdida de bytes.
- Lectura line-by-line de archivos y pipes; subshell gotcha del pipe.
- Lectura de registros null-terminated con `read -d ''` y `find -print0`.
- Control de flujo dentro del bucle: `continue`, `break`, bucles anidados con etiquetas.
- Rendimiento: builtin vs proceso externo por iteración.
- Datos externos: `curl`/`wget` + `jq` mínimo para iterar sobre JSON.

Lo que **no** cubre (se verá después):
- `getopts` / `getopt` para parsear argumentos → `sys-18`.
- `grep`/`sed`/`awk` profundo → `sys-19`.
- Descarga reproducible con firma/checksum → `sys-20`.
- Globbing avanzado (`globstar`, `extglob`), parameter expansion profunda → `sys-21`.

## Materiales

- **`theory/lesson.md`** — lección profunda, ~500 líneas en español, con tabla de patrones (bueno vs. malo con razones), el patrón null-terminated, el gotcha del subshell del pipe y nota de rendimiento.
- **`examples/`** — demostraciones ejecutables:
  - `01-iteration-good-vs-bad/` — mismo objetivo resuelto bien y mal, lado a lado.
  - `02-read-null-terminated/` — lectura de `find -print0` dentro de un array.
- **`activities/`** — dos actividades:
  - `01-safe-file-iteration/` — guided-lab, 60 min. Procesar archivos con espacios, newlines y `*` sin romperse.
  - `02-bulk-rename/` — independent, 60 min. Renombrado idempotente de fotos con `--dry-run`.
- **`resources/links.md`** — BashFAQ 1, BashPitfalls (parsing ls), tutorial corto de `jq`.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué expansiones hace Bash sobre `for f in $(ls)` y qué datos se pierden. Explicar por qué `cmd \| while read` corre el `while` en un subshell y qué consecuencias tiene. Diferenciar iteración por campos (`for`) de iteración por registros (`while read`). |
| Operativa | Procesar un árbol de archivos con nombres arbitrarios (espacios, newlines, `*`, bytes no UTF-8) sin perder datos. Leer JSON de una API con `curl` + `jq` e iterar sobre sus elementos. Hacer renombrado masivo idempotente con `--dry-run`. |
| Arquitectónica | Decidir, dado un dataset, si conviene una lectura por líneas, por bytes null-terminated o un read-into-array; justificar la elección por tamaño, forma y origen de los datos. Reconocer cuándo un bucle en Bash deja de ser razonable y conviene `awk`/Python. |

## Criterios de evaluación

- Entrega de la actividad `01-safe-file-iteration/` procesa correctamente archivos con espacios, newlines y `*` en el nombre (verificado por `tests/validate.sh`).
- Entrega de la actividad `02-bulk-rename/` es **idempotente** (ejecutarla dos veces no rompe nada) y soporta `--dry-run` (no toca el filesystem).
- Todos los scripts entregados pasan `shellcheck` sin warnings.
- Todos los scripts usan `#!/usr/bin/env bash`, `set -euo pipefail` e `IFS=$'\n\t'`.
- Respuesta argumentada a las preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entera, prestando especial atención a la tabla de patrones y al apartado del subshell del pipe.
2. Reproduce `examples/01-iteration-good-vs-bad/` ejecutando ambos scripts contra el mismo directorio de prueba y observando la diferencia.
3. Reproduce `examples/02-read-null-terminated/` y lee el `demo.sh` entendiendo por qué `-d ''` es equivalente a "separador = NUL".
4. Haz la actividad `01-safe-file-iteration/` (guiada).
5. Haz la actividad `02-bulk-rename/` (independiente).
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-17-interactive-scripts-select-dialog-zenity`: scripts que interactúan con un operador humano (`read`, `select`, `dialog`, `zenity`).
