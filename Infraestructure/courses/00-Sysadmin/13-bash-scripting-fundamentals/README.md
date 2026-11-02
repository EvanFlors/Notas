# sys-13 — Fundamentos de Bash scripting

## Identificación

- **ID:** `sys-13-bash-scripting-fundamentals`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-01-bash-cli-foundations`, `sys-02-shell-command-anatomy`.

## Objetivo

Dar el salto de **ejecutar comandos sueltos en la terminal** a **escribir un script reproducible y parametrizado**: un archivo con shebang, permisos de ejecución, variables de entrada (`$1..$n`), expansión de parámetros con defaults y validaciones, y quoting correcto. Al terminar deberías poder tomar una secuencia de comandos pegada en un README y convertirla en un script Bash que se comporta de forma predecible con cualquier entrada razonable (y falla con claridad frente a entradas rotas).

## Alcance

Este módulo cubre:

- **Shebang** (`#!/usr/bin/env bash`), modos estrictos (`set -euo pipefail`) y permisos de ejecución (`chmod +x`).
- **Parámetros posicionales**: `$0`, `$1..$9`, `${10}+`, `$#`, `$@`, `$*`.
- **Variables de shell**: asignación sin espacios, scope, exportación, `local`.
- **Quoting**: diferencias semánticas entre comillas simples (`'...'`), dobles (`"..."`) y sin comillas; cuándo cada una es correcta.
- **Expansión de parámetros**: `${var:-default}`, `${var:=default}`, `${var:?error}`, `${var:+alt}` y otras formas útiles.
- **Interpolación segura**: siempre `"${var}"`, nunca `$var` en argumentos a comandos.
- **`printf` vs `echo`**: por qué `printf` es la opción portable y predecible.
- **Comentarios y estilo** siguiendo la Google Shell Style Guide.

Lo que **no** cubre (se verá después):

- Control de flujo (`if`, `case`, loops) → `sys-14`.
- Funciones, arrays, asociativos → `sys-15`.
- Manejo de señales, traps, procesos → `sys-16`.
- Testing de scripts (`bats`, `shellcheck` en CI) → `sys-17`.

## Materiales

- **`theory/lesson.md`** — lección profunda (~450 líneas) con cheatsheet de quoting, tabla de expansión de parámetros y una conversión paso a paso de un one-liner a un script parametrizado.
- **`examples/`** — ejemplos demostrativos ejecutables:
  - `01-quoting-demo/` — mostrar en vivo cómo las comillas cambian el resultado.
  - `02-param-expansion-cheatsheet/` — formas de `${var:-...}` y familia con salida comparada.
- **`activities/`** — dos actividades:
  - `01-first-parameterized-script/` — convertir `echo "Hola mundo"` en `greet.sh` con parámetros, defaults y validación (guided, 45 min).
  - `02-quoting-dojo/` — reparar un script roto por mal quoting en archivos con espacios, globs y newlines (independent, 60 min).
- **`resources/links.md`** — referencias verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué hace exactamente el shebang y por qué `env bash` es portable. Distinguir cuándo `${var:-x}`, `${var:=x}`, `${var:?x}` y `${var:+x}` son correctos. Decir qué pasa si no entrecomillas `$1` cuando el argumento tiene espacios. |
| Operativa | Tomar un comando y envolverlo en un script ejecutable con parámetros nombrados o posicionales, defaults razonables, y mensaje de error claro cuando faltan datos. Pasar `shellcheck` sin warnings. |
| Arquitectónica | Elegir entre `printf` y `echo` según el caso. Decidir cuándo un script merece defaults implícitos (`:-`), cuándo asignar permanentemente (`:=`), y cuándo abortar (`:?`). |

## Criterios de evaluación

- Script creado con `#!/usr/bin/env bash` + `set -euo pipefail`, ejecutable, pasa `shellcheck` sin warnings.
- Acepta entrada vía parámetros posicionales y aplica un default sensato cuando no se pasa.
- Falla con mensaje legible cuando falta un parámetro obligatorio (usando `${var:?}`).
- Maneja correctamente argumentos con espacios, globs (`*`) y caracteres especiales.
- Usa `printf` para formato estructurado; usa `echo` solo para mensajes triviales sin interpretación.
- Las dos actividades (`validate.sh`) pasan.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin tocar nada).
2. Reproduce `examples/01-quoting-demo/` y observa el output de cada caso.
3. Reproduce `examples/02-param-expansion-cheatsheet/` imprimiendo los resultados.
4. Haz la actividad `activities/01-first-parameterized-script/` (guided).
5. Haz la actividad `activities/02-quoting-dojo/` (independent) — es la que valida comprensión real.
6. Vuelve a `theory/lesson.md` y responde las preguntas de reflexión sin consultar.

## Siguiente

→ `sys-14-bash-control-flow`: `if`, `case`, bucles `for`/`while`/`until`, `[[ ]]` vs `[ ]`, patrones condicionales, y cómo elegir estructura según la forma del dato.
