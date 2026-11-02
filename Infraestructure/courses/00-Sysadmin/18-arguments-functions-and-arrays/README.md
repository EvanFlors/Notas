# sys-18 — Argumentos, funciones y arrays

## Identificación

- **ID:** `sys-18-arguments-functions-and-arrays`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-14-robust-scripts-and-error-handling`, `sys-15-arithmetic-tests-and-conditionals`.

## Objetivo

Estructurar scripts de **≥ 300 líneas** con argumentos parseados, funciones reutilizables y arrays (indexados y asociativos). Al terminar, deberías escribir CLIs que sigan convenciones POSIX (`-h`, `--`, códigos de salida), aislar lógica en funciones con alcance controlado (`local`), y modelar configuración con arrays asociativos.

## Alcance

Este módulo cubre:

- **Parámetros posicionales:** `$0`, `$1..$N`, `$#`, `$@` vs `$*` (con y sin comillas), `shift`, separador `--`.
- **`getopts` (builtin POSIX):** opciones cortas, `OPTARG`, `OPTIND`, opciones con y sin argumento, errores de parseo, reset de estado.
- **`getopt` GNU (external):** opciones largas (`--output=FILE`), reordenamiento, limitaciones de portabilidad.
- **Convenciones CLI:** `--help`, `--version`, exit codes (`0` éxito, `1` genérico, `2` uso), mensajes a `stderr`.
- **Funciones:** declaración (`name() { ... }` y `function name { ... }`), paso de argumentos (`$1..$N` dentro), alcance (shell variables son globales por defecto), `local` y `declare -r`, `return` solo 0–255, captura de salida con `$(func)`.
- **Arrays indexados:** `arr=(a b c)`, `arr[0]`, `${arr[@]}` vs `${arr[*]}`, `${#arr[@]}`, `${arr[@]:1:2}` (slicing), `+=`, `unset`.
- **Arrays asociativos:** `declare -A map`, `map[key]=value`, iteración `for k in "${!map[@]}"`, orden no garantizado.
- **Paso de arrays a funciones:** por nombre con `declare -n ref=$1` (nameref, Bash 4.3+).

Lo que **no** cubre (se verá después):

- `trap`, `EXIT`, señales → repasado en `sys-14` y profundizado en `sys-19`.
- Expresiones regulares extendidas en `[[ =~ ]]` → `sys-19`.
- Herramientas de texto (`awk`, `sed` avanzado) → `sys-21`.
- Debugging con `set -x` y `BASH_XTRACEFD` → `sys-22`.

## Materiales

- **`theory/lesson.md`** — lección profunda (~600 líneas) con tabla comparativa `$@`/`$*`, plantilla `getopts`, plantilla `getopt` largo, demo de `local`, patrón de iteración de arrays asociativos.
- **`examples/`** — ejemplos demostrativos ejecutables:
  - `01-getopts-template/` — plantilla canónica de `getopts` con `-h`, `-v`, flags con y sin argumento.
  - `02-functions-and-arrays/` — demo de funciones (scope, `local`, return/captura) y arrays (indexados + asociativos + nameref).
- **`activities/`** — dos actividades:
  - `01-cli-with-getopts/` — construir una CLI con `-v`, `-o FILE`, `-n COUNT`, `-h`, ARG posicional (guided-lab, 75 min).
  - `02-refactor-to-functions/` — refactorizar un monolito de 150 líneas en funciones + `main` + array asociativo de configuración (independent, 75 min).
- **`resources/links.md`** — Bash manual (Positional Parameters, Arrays, Shell Functions), BashFAQ sobre `getopts`.

## Temas y subtemas

| Bloque | Subtemas |
|--------|----------|
| Posicionales | `$0`, `$1..$9`, `${10}`, `$#`, `$@`, `$*`, `shift [N]`, `--`. |
| Comillas en `$@`/`$*` | `"$@"` → N palabras, `"$*"` → una cadena con `IFS`. |
| `getopts` | Loop `while getopts "ho:vn:" opt`, `OPTARG`, `OPTIND`, `OPTERR=0`, `shift $((OPTIND-1))`. |
| `getopt` largo | `getopt -o ho:vn: -l help,output:,verbose,count: -- "$@"`, `eval set --`. |
| Convenciones | `--help`/`-h` → exit 0, uso erróneo → exit 2, errores → `stderr`. |
| Funciones | sintaxis, `return` 0–255, captura `out=$(func)`, scope global por defecto. |
| `local`/`declare` | `local -r`, `local -i`, `local -a`, `local -A`, shadowing. |
| Arrays indexados | creación, acceso, longitud, iteración, slicing, append, `unset arr[i]` deja huecos. |
| Arrays asociativos | `declare -A`, claves string, `${!map[@]}`, orden impredecible. |
| Namerefs | `declare -n ref=$1` para pasar arrays por referencia a funciones. |

## Conceptos internos clave

- **`"$@"` vs `"$*"`:** `"$@"` expande a N palabras separadas (una por argumento, preservando espacios internos). `"$*"` concatena con el primer carácter de `IFS`. Sin comillas, ambos sufren word-splitting y glob expansion → **siempre usa `"$@"`** para forwardear argumentos.
- **`OPTIND` persiste entre invocaciones:** si llamas `getopts` desde una función reutilizable debes hacer `local OPTIND=1` o resetear manualmente, si no la segunda invocación empieza donde quedó la primera.
- **`return` ≠ `exit`:** `return` solo acepta 0–255 (int unsigned 8-bit), vuelve al caller. `exit` termina el proceso. Capturar salida real se hace con `echo` + `$(func)`, no con `return`.
- **Scope de variables en Bash:** por defecto todo es global al script. `local` solo tiene efecto dentro de una función y crea **dynamic scoping** (visible a funciones llamadas), no lexical.
- **Arrays no se exportan:** `export arr` no funciona para arrays — se pierden al cruzar `exec`/`env`. Hay que serializar (`declare -p`) o pasar como argumentos.
- **Nameref (`declare -n`):** crea un alias por nombre; cambios en la ref modifican la original. Es la única forma limpia de pasar un array por referencia a una función.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `"$@"` es correcto y `$@` no lo es. Describir cuándo `OPTIND` necesita reset. Diferenciar `return` (código 0–255) de capturar `echo` por `$(func)`. Justificar `local` como barrera de aislamiento. |
| Operativa | Parsear flags cortos con `getopts`, flags largos con `getopt`, imprimir `--help` consistente, construir funciones con parámetros y capturar su salida, iterar arrays asociativos y pasarlos por nameref. |
| Arquitectónica | Decidir cuándo partir un script en funciones (regla práctica: cualquier bloque > 20 líneas que haga una sola cosa). Elegir array indexado vs asociativo (orden/índice numérico vs lookup por clave). Evitar duplicar `OPTIND`/estado global entre funciones. |

## Criterios de evaluación

- Script que compile con `bash -n` y pase `shellcheck -S warning` sin findings.
- `--help` y uso erróneo con mensajes diferenciados (`stderr` para errores) y exit codes correctos (`0` vs `2`).
- Al menos una función con `local` y argumentos, llamada desde `main`.
- Al menos un array asociativo iterado con `"${!map[@]}"`.
- Prueba de que `shift $((OPTIND-1))` deja los posicionales listos para el ARG.
- Respuesta argumentada a las preguntas de evaluación al final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin memorizar).
2. Reproduce `examples/01-getopts-template/` ejecutando con distintos flags.
3. Reproduce `examples/02-functions-and-arrays/` observando scope y nameref.
4. Haz `activities/01-cli-with-getopts/` (guiada, 75 min) — construye la CLI base.
5. Haz `activities/02-refactor-to-functions/` (independiente, 75 min) — refactoriza el monolito.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-19`: pattern matching (`case`), regex (`[[ =~ ]]`), `trap` y señales en scripts grandes.
