# sys-02 — Anatomía de un comando de shell

## Identificación

- **ID:** `sys-02-shell-command-anatomy`
- **Curso:** `00-Sysadmin`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-01-bash-cli-foundations` (redirección, pipes, variables de entorno).

## Objetivo

Descomponer cualquier línea de comandos en sus partes (**comando · opciones cortas/largas · argumentos · separadores · operadores**) y, sobre todo, **leer autónomamente la documentación**. Al terminar deberías abrir un `man` desconocido, saltar a la sección correcta y encontrar un flag concreto en menos de 30 segundos.

## Alcance

Este módulo cubre:

- Anatomía canónica `cmd [GLOBAL_OPTS] subcmd [OPTS] [ARGS...]`.
- Convenciones de opciones: cortas (`-l`), largas (`--long`), agrupadas (`-la`), con valor (`-oValue`, `--opt=value`, `--opt value`).
- Argumentos posicionales, flags booleanos y el separador `--`.
- Separadores y operadores de shell: `;`, `&&`, `||`, `&`, `|`, `( … )`, `{ …; }`.
- Fuentes de documentación: `--help`, `man`, `info`, `tldr`, `apropos`, `whatis`.
- Secciones de manpages (1 user, 2 syscalls, 3 libc, 5 formats, 7 misc, 8 admin).
- **Categorización canónica** de los comandos de un sistema Unix (navegación, FS, viewing, stream editing, searching, procesos, red, usuarios, paquetes, servicios, disco, archivadores, checksums, meta de shell).
- Cómo Bash parsea una línea (tokenización → expansión → ejecución) y dónde se buscan los comandos (`PATH`, `hash -l`).

Lo que **no** cubre (se verá después):

- Expansión avanzada (parameter, process substitution) → `sys-21`.
- Regex y procesamiento de texto a profundidad → `sys-19`.
- `getopts`/`getopt` para escribir tus propias CLIs → `sys-18`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones y la tabla de categorías como centro.
- **`examples/`** — dos ejemplos demostrativos:
  - `01-same-tar-many-ways/` — tres sintaxis equivalentes para extraer un `.tar.gz`.
  - `02-man-section-tour/` — mismo nombre (`printf`, `passwd`) en distintas secciones de `man`.
- **`activities/`** — dos actividades:
  - `01-categorize-the-coreutils/` — clasificar 40 comandos (independent, 45 min).
  - `02-manpage-scavenger-hunt/` — búsqueda guiada en 10 manpages (challenge, 45 min).
- **`resources/links.md`** — fuentes verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Distinguir sin ejecutar nada `tar -xzf`, `tar xzf` y `tar --extract --gzip --file=`. Describir qué hace Bash entre pulsar Enter y lanzar el binario. Diferenciar builtin, función, alias y binario externo. |
| Operativa | Abrir `man 5 passwd` sin dudar sobre la sección. Encontrar un flag con `/pattern` + `n`/`N` en menos de 30 s. Resolver un comando desconocido con `apropos` + `whatis` + `tldr` sin tocar un buscador. |
| Arquitectónica | Reconocer convenciones de CLI (POSIX `getopt(3)`, GNU `argp`, subcomandos tipo `git`/`kubectl`/cobra) y aplicarlas al diseñar tus propios scripts. |

## Criterios de evaluación

- Tabla personal de 40 comandos clasificados por categoría con una línea de uso cada uno (`activities/01`).
- 10 respuestas correctas al scavenger hunt de manpages, cada una citando la sección y el flag concreto (`activities/02`).
- Capacidad de ejecutar `type -a <cmd>`, `command -V <cmd>`, `hash -l` y explicar la salida.
- Respuesta argumentada a las preguntas de evaluación al final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada; la tabla de categorías es para consultar, no memorizar).
2. Reproduce `examples/01-same-tar-many-ways/` ejecutando cada forma.
3. Reproduce `examples/02-man-section-tour/`; observa cómo cambia el contenido según la sección.
4. Haz `activities/01-categorize-the-coreutils/` (es la que valida el modelo mental de categorías).
5. Haz `activities/02-manpage-scavenger-hunt/` como cierre y gimnasio de lectura de docs.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-03-unix-files-and-filesystem`: tipos de archivo, inodos, FHS, `find` seguro frente a nombres raros.
