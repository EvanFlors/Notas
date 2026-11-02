# sys-21 — Bash en profundidad (avanzado)

## Identificación

- **ID:** `sys-21-bash-depths-advanced`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-18`, `sys-19` (I/O avanzado, funciones y modularidad).

## Objetivo

Dominar las **internals de Bash** para resolver casos complicados **sin tener que reescribir en otro lenguaje**. Al terminar deberías poder: predecir el output de una línea con múltiples expansiones (brace, tilde, parámetros, aritmética, comando, splitting y globbing) sin ejecutarla; reemplazar archivos temporales por **process substitution**; abrir y multiplexar descriptores de archivo con `exec`; usar `coproc` y FIFOs cuando process substitution no alcanza; y decidir con criterio entre `#!/bin/sh` y `#!/usr/bin/env bash` sabiendo exactamente qué pierdes.

## Alcance

Este módulo cubre:

- **Orden de expansión** de Bash: brace → tilde → parámetros/aritmética → sustitución de comandos → word splitting → pathname (globbing). Por qué este orden explica el 90 % de los bugs raros.
- **Globbing avanzado**: `shopt -s nullglob globstar extglob dotglob failglob` y en qué momento activar cada uno.
- **Parameter expansion** avanzado: prefijo/sufijo (`#`, `##`, `%`, `%%`), reemplazo (`/`, `//`), cambio de caja (`^^`, `,,`), defaults (`:-`, `:=`, `:?`, `:+`), longitud (`#`), substrings (`:offset:length`).
- **Process substitution** `<(cmd)` y `>(cmd)`: cuándo evita un `mktemp` y cuándo **no** se puede usar (herramientas que hacen `lseek`).
- **Coprocesses** (`coproc`): proceso en background con sus FDs capturados en un array, útil para dialogar con un filtro de larga vida.
- **FDs explícitos**: `exec 3>file`, `exec {fd}<file`, `exec 3>&-`. Multiplexar logs, abrir sockets, mantener un lock abierto.
- **Named pipes** (`mkfifo`): sincronización productor/consumidor entre procesos no emparentados.
- **`IFS`**: por qué `IFS=$'\n\t'` es defensivo y qué rompe cuando lo cambias.
- **`trap … DEBUG`** y **`trap … RETURN`**: tracing fino para depurar sin `set -x`.
- **Introspección**: `BASH_SOURCE`, `BASH_LINENO`, `FUNCNAME` para construir stack traces.
- **Atributos**: `declare -r` (readonly), `-x` (export), `-A` (array asociativo), `-i` (integer), `-n` (nameref).
- **Portabilidad**: cuándo `#!/bin/sh` y cuándo `#!/usr/bin/env bash`; qué pierdes en dash y busybox ash.

Lo que **no** cubre:

- Testing con `bats-core` → módulo de calidad.
- Empaquetado y distribución de scripts como paquetes → fuera de alcance.
- Expresiones regulares de `[[ … =~ … ]]` más allá de un recordatorio → se vio en `sys-15`.

## Materiales

- **`theory/lesson.md`** — lección profunda (~700 líneas) con: diagrama del orden de expansión, ejemplo trazado paso a paso (`echo {a,b}/*.txt > >(tee out) 2>&1`), tabla de operadores de parameter expansion, tabla de opciones de globbing con ejemplos, patrones de process substitution, demo con FIFO, matriz de portabilidad bash vs dash vs busybox ash.
- **`examples/`**:
  - `01-expansion-order-walkthrough/` — un `demo.sh` que **imprime** cada etapa de expansión para ver el orden en vivo.
  - `02-process-substitution-patterns/` — `diff <(cmd1) <(cmd2)` y tee a múltiples sinks (`tee >(gzip > a.gz) >(sha256sum > a.sha)`).
- **`activities/`**:
  - `01-expansion-oracle/` — **independent** (60 min): el estudiante **predice** el output de 15 snippets antes de ejecutarlos; `validate.sh` ejecuta cada uno y compara.
  - `02-replace-tempfiles-with-procsub/` — **debug** (60 min): un script legacy escribe tres archivos temporales, los compara y los limpia; hay que reescribirlo con process substitution verificando outputs idénticos y **sin dejar nada en `/tmp`**.
- **`resources/links.md`** — Bash Reference Manual (Expansions, Shell Options, Redirections), BashGuide, `shopt(1)`, docs de `coproc`.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar el orden de expansión de Bash sin consultar. Explicar por qué `${arr[*]}` sin comillas se "aplana" distinto que `${arr[@]}`. Decir qué hace exactamente `shopt -s nullglob` y qué rompe en scripts que esperaban que un glob sin match se expandiera a sí mismo. |
| Operativa | Reescribir un script que usa `mktemp` por uno con process substitution cuando sea aplicable. Abrir un FD con `exec`, escribirle y cerrarlo. Construir un stack trace con `BASH_SOURCE`/`BASH_LINENO`/`FUNCNAME`. Usar `${var##*/}` y `${var%.*}` sin pensar. |
| Arquitectónica | Decidir entre process substitution, coproc y FIFO según el patrón de I/O (unidireccional, bidireccional, entre procesos no emparentados). Elegir el shebang (`sh` vs `bash`) con criterio: qué portabilidad ganas y qué funciones pierdes. |

## Criterios de evaluación

- Las dos actividades pasan `tests/validate.sh`.
- Scripts entregados comienzan con `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`.
- `shellcheck -S warning` pasa con 0 findings sobre todo lo entregado.
- Puedes responder sin consultar: ¿qué expansión ocurre antes, word splitting o pathname? ¿Qué devuelve `${foo:-bar}` si `foo` está sin definir? ¿Y `${foo:=bar}`? ¿Por qué `diff <(sort a) <(sort b)` no deja temporales y `diff $(sort a) $(sort b)` ni siquiera compila mentalmente?

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-expansion-order-walkthrough/` ejecutando `demo.sh` paso a paso.
3. Reproduce `examples/02-process-substitution-patterns/` y lanza `ls /tmp` antes y después para constatar que no deja basura.
4. Haz `activities/01-expansion-oracle/` **prediciendo primero** y luego ejecutando `validate.sh`.
5. Haz `activities/02-replace-tempfiles-with-procsub/` sin mirar la solución hasta pasar tests o anclarte 20 min.
6. Responde las preguntas de reflexión al final de la lección.

## Siguiente

→ Módulo posterior de calidad/testing de bash (`bats-core`) o salida del tramo bash hacia observabilidad (`sys-20` y adelante según roadmap).
