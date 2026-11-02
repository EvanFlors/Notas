# sys-14 — Scripts robustos y manejo de errores

## Identificación

- **ID:** `sys-14-robust-scripts-and-error-handling`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-13-bash-scripting-fundamentals` (variables, quoting, expansiones, `#!/usr/bin/env bash`, invocar scripts y leer su exit code).

## Objetivo

Pasar de scripts que "funcionan si todo va bien" a scripts que **fallan temprano, claro y limpiamente**. Al terminar deberías poder: encender la trinidad `-euo pipefail` con criterio (sabiendo qué **no** cubre), instrumentar `trap` para cleanup y señales, serializar invocaciones concurrentes con `flock`, separar logs por severidad y canal, elegir exit codes semánticos y pasar `shellcheck -S warning` sin findings.

## Alcance

Este módulo cubre:

- `set -e`, `set -u`, `set -o pipefail`, `set -x`: qué hace cada uno y por qué los activamos juntos.
- Límites de `set -e`: contextos donde **no** aborta (ramas de `if`, condiciones de `while`/`until`, operandos de `&&`/`||`, pipelines sin `pipefail`, subshells, funciones usadas en condicionales).
- `trap`: handlers para `EXIT` (cleanup incondicional), `ERR` (reporte con línea y comando), `INT`/`TERM` (cancelación limpia).
- Idempotencia: diseñar scripts seguros de reejecutar (mismo input → mismo estado final).
- Lock files con `flock -n` (y la alternativa `mkdir` atómico) para evitar ejecuciones solapadas.
- Logging: stdout vs stderr, niveles `INFO`/`WARN`/`ERROR`, timestamping, prefijado por severidad.
- Exit codes semánticos: `0` éxito, `1` error genérico, `2` uso incorrecto, rango `64-78` de `sysexits.h` (BSD).
- `shellcheck` como gate de calidad: cómo leer sus códigos (`SC2086`, `SC2155`, …) y silenciarlos con criterio.

Lo que **no** cubre (se verá después):

- Aritmética, tests y condicionales → `sys-15`.
- Bucles e iteración → `sys-16`.
- Testing de bash con `bats-core` → módulo posterior de calidad.

## Materiales

- **`theory/lesson.md`** — lección profunda (~500 líneas): fundamentos de `set`, tabla de gotchas de `-e`, patrones de `trap`, idioma de `flock -n`, librería mínima de logging, tabla de exit codes.
- **`examples/`**:
  - `01-set-e-gotchas/` — 5 scripts que demuestran los casos donde `set -e` **no** aborta.
  - `02-trap-cleanup-template/` — plantilla reusable con `trap EXIT` + `trap ERR` + tmpdir seguro.
- **`activities/`**:
  - `01-trap-and-lock/` — guided-lab (60 min): un job que sobrevive a invocaciones concurrentes duplicadas (vía `flock -n`) y limpia su tmpdir en cualquier salida (incluyendo `SIGINT`).
  - `02-shellcheck-cleanup/` — debug (45 min): tomar un script "sucio" y dejarlo pasando `shellcheck -S warning` con cero findings.
- **`resources/links.md`** — Bash manual (`set`, `trap`), BashFAQ 105, shellcheck wiki.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `-e` **no** aborta en `cmd && other` o dentro de `if cmd; then`. Diferenciar `trap ... EXIT` de `trap ... ERR` y cuándo elegir uno u otro. Decir qué protege `flock -n` que `test -f lockfile` no. |
| Operativa | Escribir un script con `-euo pipefail` + `IFS=$'\n\t'` + `trap` de cleanup + `flock -n` + logging por niveles y exit code semántico. Correr `shellcheck -S warning` y arreglar sus findings con criterio. |
| Arquitectónica | Decidir cuándo un error merece abortar vs. loggear y continuar. Elegir idempotencia vs. locking según naturaleza del job (reentrante vs. exclusivo). Elegir exit codes útiles para que un orquestador reaccione distinto a cada tipo de fallo. |

## Criterios de evaluación

- Las dos actividades pasan `tests/validate.sh`.
- Los scripts entregados comienzan con `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`.
- `shellcheck -S warning` corre con 0 findings sobre todo lo entregado (silenciando con `# shellcheck disable=` solo cuando se justifica en un comentario adjunto).
- Puedes responder sin consultar: ¿qué pasa si en `cmd1 | cmd2` falla `cmd1` sin `pipefail`? ¿y con `pipefail`? ¿por qué `trap 'rm -rf $tmp' EXIT` es más seguro que un `rm -rf` al final del script?

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-set-e-gotchas/` ejecutando cada caso y leyendo el exit code.
3. Lee `examples/02-trap-cleanup-template/` y usa su plantilla como base mental.
4. Haz `activities/01-trap-and-lock/` (guided, 60 min). No mires la solución hasta pasar tests o anclarte 20 min.
5. Haz `activities/02-shellcheck-cleanup/` (debug, 45 min). Lee el código antes de ejecutar `shellcheck`.
6. Responde las preguntas de reflexión de la lección sin consultar.

## Siguiente

→ `sys-15-arithmetic-tests-and-conditionals`.
