# sys-01 — Bash & CLI foundations

## Identificación

- **ID:** `sys-01-bash-cli-foundations`
- **Curso:** `00-Sysadmin`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** ninguno (acceso a una terminal Linux/macOS o WSL).

## Objetivo

Operar la shell **interactivamente** con fluidez: moverte por el filesystem, gestionar archivos, redirigir entradas y salidas con precisión, encadenar comandos con pipes y controlar el entorno mediante variables. Al terminar, deberías poder describir qué pasa cuando pulsas Enter sobre `ls -l | grep foo > out.txt 2>&1`, byte a byte.

## Alcance

Este módulo cubre:

- Qué es una *shell*, qué es *Bash* y en qué se diferencia de `sh`.
- El prompt (`PS1`), el historial (`history`, `!!`, `!$`, `Ctrl-R`) y la librería *readline*.
- Navegación: `pwd`, `cd`, `pushd/popd`, `~`, `-`, `OLDPWD`.
- Gestión de archivos: `ls`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `ln`, `stat`.
- Standard I/O (fd 0/1/2) y el modelo de descriptores de archivo.
- Redirección completa: `>`, `>>`, `<`, `2>`, `2>>`, `2>&1`, `&>`, `<<<`, `<<EOF`.
- Pipes: `|`, `|&` y `set -o pipefail`.
- `tee` para bifurcar flujos y auditar pipelines.
- Variables de entorno vs. variables de shell: `export`, `env`, `set`, `unset`, `printenv`.
- Variables canónicas: `PATH`, `HOME`, `PWD`, `OLDPWD`, `SHELL`, `LANG`/`LC_*`, `TERM`.
- **Internals:** `fork()` + `execve()`, builtin vs función vs alias vs externo, tabla de file descriptors, herencia de entorno padre→hijo.

Lo que **no** cubre (se verá después):

- Anatomía de la línea de comandos y manpages → `sys-02`.
- Permisos, FHS y tipos de archivo UNIX → `sys-03`.
- Scripting (if/for/case, funciones, manejo de errores) → `sys-04`.
- Procesos y señales → `sys-05`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos ejecutables:
  - `01-prompt-and-readline/` — construir un `PS1` útil y recorrido por readline.
  - `02-redirection-matrix/` — matriz comparativa de todos los operadores con demos.
- **`activities/`** — dos actividades:
  - `01-cli-tour/` — tour guiado por navegación, gestión de archivos e historial (guided-lab).
  - `02-io-redirection-dojo/` — ejercicios independientes de redirección, pipes y variables (independent).
- **`resources/links.md`** — manuales y referencias verificables.

## Temas y subtemas

| Bloque | Subtemas |
|--------|----------|
| Shell | shell vs Bash vs `sh`, modos interactivo/no interactivo, login vs non-login. |
| Prompt y readline | `PS1`/`PS2`, `history`, `HISTCONTROL`, `HISTSIZE`, bindings básicos (`Ctrl-A`, `Ctrl-E`, `Ctrl-R`, `Alt-.`). |
| Navegación | `pwd -P` vs `pwd -L`, `cd -`, pila con `pushd`/`popd`/`dirs`. |
| Archivos | `ls -lhiA`, `cp -a`, `mv`, `rm -I`, `mkdir -p`, `touch -r`, `ln -s`, `stat -c`. |
| I/O | fd 0/1/2, dup, cierre con `>&-`. |
| Redirección | `>`, `>>`, `<`, `2>`, `2>&1`, `&>`, `<<<`, `<<EOF`, `<<-EOF`, `<<'EOF'`. |
| Pipes | `|`, `|&`, `set -o pipefail`, `PIPESTATUS`. |
| `tee` | split, `-a` append, logging a múltiples destinos. |
| Entorno | `set` vs `env`, `export`, `unset`, `declare -p`, `printenv`. |
| Variables canónicas | `PATH` y seguridad, `HOME`, `PWD`/`OLDPWD`, `LANG`/`LC_ALL`, `TERM`. |

## Conceptos internos clave

- **`fork()` + `execve()`:** por cada comando externo la shell `fork()` y el hijo `execve()` el binario; builtins no — se ejecutan en el mismo proceso.
- **Resolución de comandos:** alias → función → builtin → ejecutable en `PATH`. Herramientas: `type -a`, `command -V`, `which -a`.
- **File descriptors:** tabla por proceso; `0=stdin`, `1=stdout`, `2=stderr`; se heredan al `fork()`; la redirección manipula esta tabla antes del `exec()`.
- **Herencia de entorno:** solo variables **exportadas** entran en `environ` y los hijos las ven; las shell variables no.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Describir en orden qué hace Bash al ejecutar `cmd a b > out 2>&1`: parse, fork, dup, exec. Diferenciar shell variable vs variable de entorno. Explicar por qué `A=1 cmd` y `export A=1; cmd` dan resultados visibles distintos al proceso. |
| Operativa | Redirigir stdout y stderr a archivos separados o combinados, construir pipelines con `pipefail`, auditar con `tee`, construir un `PS1` legible, modificar `PATH` sin romperlo. |
| Arquitectónica | Decidir cuándo exportar una variable y cuándo mantenerla local al script. Elegir entre `>` y `>>` con criterio. Justificar `set -euo pipefail` como baseline. |

## Entregables

- Un `~/.bashrc` (o fragmento) con **prompt informativo**, **aliases útiles** e **`HISTCONTROL=ignoredups:erasedups`** aplicado.
- Scripts de las actividades que pasan `tests/validate.sh` y `shellcheck` sin warnings.
- Respuestas a las preguntas de evaluación de la lección sin consultar.

## Criterios de evaluación

- Uso correcto de `2>&1` vs `&>` (sabes la diferencia semántica y portabilidad POSIX).
- Distinción clara entre `export` y asignación local; nunca "exportas por si acaso".
- Sin `rm -rf` sin ruta explícita y absoluta; nunca `rm -rf $VAR/` sin `set -u`.
- Pipelines con `set -o pipefail` cuando el fallo de un paso intermedio importa.
- Prompt que muestre al menos: usuario, host, cwd abreviado y último exit code.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Reproduce `examples/01-prompt-and-readline/` y adapta tu `PS1`.
3. Lee `examples/02-redirection-matrix/` como material de referencia activo.
4. Haz `activities/01-cli-tour/` (guided-lab) para fijar reflejos.
5. Haz `activities/02-io-redirection-dojo/` (independent) para consolidar redirección y entorno.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-02-shell-command-anatomy`: descomponer cualquier línea de comandos, leer manpages con eficiencia y mapear el zoológico de coreutils.
