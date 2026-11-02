# sys-15 — Aritmética, tests y condicionales en Bash

## Identificación

- **ID:** `sys-15-arithmetic-tests-and-conditionals`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-13-bash-scripting-fundamentals`

## Objetivo

Usar **variables numéricas**, **operadores aritméticos** y la cláusula **`if`** con los operadores de test correctos. Al terminar deberías poder leer un script ajeno y decir en segundos si cada condición compara archivos, strings o números, y por qué usa `[` o `[[ ]]`.

## Alcance

Este módulo cubre:

- Variables numéricas: `declare -i`, promoción implícita en contextos aritméticos.
- Aritmética: `$(( ))` (expansión), `(( ))` (comando), `let`, `expr` (legacy POSIX) y `bc` para floats.
- Operadores aritméticos: `+ - * / % **` y comparadores `< > <= >= == != && ||` dentro de `(( ))`.
- Tests: `[` (`test`), `[[ ]]` (keyword de Bash), diferencia operacional entre ambos.
- Operadores de archivo: `-f`, `-d`, `-r`, `-w`, `-x`, `-s`, `-e`, `-h`.
- Operadores de string: `-z`, `-n`, `=`, `!=`, `=~` (regex, sólo `[[ ]]`).
- Operadores numéricos de `test`: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`.
- `if` / `elif` / `else` / `fi`.
- `case ... esac` con patrones glob y alternación `|`.

Lo que **no** cubre (se verá después):

- Bucles `for`/`while` → `sys-16`.
- Interacción `read` / `select` / `dialog` → `sys-17`.
- Parsing de argumentos y funciones → `sys-18`.

## Materiales

- **`theory/lesson.md`** — lección profunda (~500 líneas) con tablas de operadores, tabla comparativa `[` vs `[[`, `case` resuelto con globs y `|`, demo de floats con `bc`, y análisis del pitfall `[ $x = $y ]` sin comillas.
- **`examples/`** — ejemplos demostrativos:
  - `01-test-operator-matrix/` — matriz imprimible con el resultado real de cada operador sobre entradas controladas.
  - `02-arithmetic-and-bc/` — aritmética entera con `(( ))` y punto flotante con `bc -l`.
- **`activities/`** — dos actividades:
  - `01-choose-the-right-test/` (independent, 45 min) — elegir el operador correcto en 15 escenarios.
  - `02-arithmetic-report/` (guided-lab, 60 min) — leer un CSV, calcular `sum/avg/min/max` y clasificar filas con `case`.
- **`resources/links.md`** — Bash manual (Conditional Expressions, Arithmetic Expansion), Greg's Wiki `BashFAQ/031`, página `test(1)`.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `[[ $x = $y ]]` no se rompe cuando `x=""` y `[ $x = $y ]` sí. Decir qué contexto activa `-eq` vs `==` vs `=`. Diferenciar `$(( ))`, `(( ))` y `[[ ]]` por valor de retorno. |
| Operativa | Escribir un `if` con comparación numérica, de string y de archivo sin consultar docs. Hacer aritmética entera con `(( ))` y de precisión arbitraria con `bc -l`. Resolver un `case` con `*.log`, `*.gz` y `?` glob. |
| Arquitectónica | Elegir `[[ ]]` por defecto en Bash y justificar cuándo se mantiene `[ ]` por portabilidad POSIX. Decidir entre `if`/`elif` encadenado y `case` según la forma de la entrada. |

## Criterios de evaluación

- 15/15 operadores correctos en `activities/01`.
- `activities/02` imprime `sum`, `avg`, `min`, `max` consistentes con el CSV y clasifica cada fila con `case`.
- Ningún `[ $var … ]` sin comillas en los scripts entregables.
- `shellcheck` limpio sobre todos los `.sh` del alumno.
- Respuesta argumentada a las preguntas de evaluación al final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero una vez; no te detengas en pitfalls todavía.
2. Reproduce `examples/01-test-operator-matrix/` ejecutando el script y leyendo la salida.
3. Reproduce `examples/02-arithmetic-and-bc/` observando qué pasa con `/` entero vs `bc -l`.
4. Vuelve a `theory/lesson.md` y re-lee la tabla `[` vs `[[` y el pitfall de comillas.
5. Haz `activities/01-choose-the-right-test/` sin ejecutar nada — es decidir operador, no escribir código.
6. Haz `activities/02-arithmetic-report/` escribiendo el script de cero contra el CSV.
7. Pasa `shellcheck` a tu solución y arregla cada aviso antes de comparar con `solution/`.

## Siguiente

→ `sys-16-loops-and-iteration`: iterar colecciones (archivos, líneas, pipes) sin pisar los pitfalls clásicos de word-splitting.
