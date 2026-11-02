# sys-17 — Scripts interactivos: `read`, `select`, `dialog`/`whiptail`, `zenity`

## Identificación

- **ID:** `sys-17-interactive-scripts-select-dialog-zenity`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-16-loops-and-iteration` (bucles, pipelines, estructuras de control).

## Objetivo

Construir scripts que **interactúan con un operador humano** cuando corresponde, y que **se comportan correctamente cuando no hay humano** (CI, cron, pipes). Elegir con criterio entre `read`, `select`, `dialog`/`whiptail` (ncurses) y `zenity` (GTK), y diseñar scripts **duales**: aceptan flags para automatización y caen a prompts cuando se invocan interactivamente.

## Alcance

Este módulo cubre:

- Builtin `read` y sus modos: `-p` (prompt), `-s` (silencioso, contraseñas), `-t` (timeout), `-a` (array), `-r` (sin interpretar backslashes), `-n` (N caracteres), `-N` (exacto N).
- Builtin `select` para menús TUI puros, sin dependencias externas.
- `dialog(1)` y `whiptail(1)`: menús ncurses, `--yesno`, `--inputbox`, `--passwordbox`, `--checklist`, `--radiolist`, `--gauge` (barra de progreso).
- `zenity(1)` para contextos de escritorio GTK.
- Confirmaciones defensivas (`y/N` seguro por defecto a "no").
- Detección de TTY (`[[ -t 0 ]]`, `[[ -t 1 ]]`) para activar o desactivar el modo interactivo.
- Patrón **dual mode**: el mismo script responde a `--yes --target /opt --components a,b` y a doble clic / invocación sin argumentos.
- Decisión arquitectónica: cuándo exigir flags, cuándo preguntar.

Lo que **no** cubre (se verá después):
- Parseo serio de argumentos con `getopts` / `getopt` → `sys-18`.
- TUIs ricas (`fzf`, `gum`, `tview`) — se mencionan en recursos como alternativa moderna.

## Materiales

- **`theory/lesson.md`** — lección profunda en español, ~500 líneas, con matriz de selección de herramienta, accesibilidad, detección de no-TTY y patrón dual-mode.
- **`examples/`** — ejemplos demostrativos:
  - `01-select-menu/` — menú puro Bash con `select`, sin dependencias.
  - `02-dialog-vs-whiptail-vs-zenity/` — el mismo menú implementado en los tres backends; comparación lado a lado.
- **`activities/`** — dos actividades:
  - `01-select-menu-runbook/` — runbook de operaciones con `select` (status / tail logs / restart / exit). *Guided-lab, 60 min*.
  - `02-dialog-based-installer/` — instalador con `dialog`, checklist de componentes y gauge de progreso, con fallback a `select` si `dialog`/`whiptail` no están instalados. *Mini-project, 60 min*.
- **`resources/links.md`** — manpages (`dialog(1)`, `whiptail(1)`, `zenity(1)`) y referencias al Bash manual (builtins `read` y `select`).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre un script interactivo y uno "driven by flags". Diferenciar TTY vs. pipe (`[[ -t 0 ]]`). Entender por qué `read` sin `-r` es casi siempre un bug. Justificar cuándo `select` basta y cuándo pedir una TUI real. |
| Operativa | Pedir contraseñas sin eco, menús con `select`, confirmaciones `y/N`, checklists con `dialog --checklist`, barras de progreso con `dialog --gauge`. Detectar y abortar si falta una dependencia opcional, cayendo a un backend más simple. |
| Arquitectónica | Diseñar un script dual-mode: en CI consume solo flags y nunca pregunta; en una sesión interactiva, si faltan datos, pregunta en lugar de fallar. Decidir cuándo `zenity` es apropiado (desktop) y cuándo es dañino (servidor headless). |

## Criterios de evaluación

- `activities/01` termina con `validate.sh` en verde: el runbook ofrece las 4 opciones, re-ingresa al menú tras cada acción y sale limpiamente.
- `activities/02` termina con `validate.sh` en verde: el instalador acepta `--non-interactive` + flags, en modo interactivo pregunta por directorio, componentes y confirma antes de "instalar".
- Todos los scripts entregados pasan `shellcheck` sin warnings `error`/`warning`.
- El estudiante responde: *"¿Cuándo exigirías flags en lugar de preguntar?"* y *"¿Qué pasa si tu script interactivo se ejecuta en un cron?"*.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Ejecuta `examples/01-select-menu/files/demo.sh` y entiende cada rama.
3. Compara los tres scripts de `examples/02-dialog-vs-whiptail-vs-zenity/files/` (si tienes solo uno instalado, lee los otros).
4. Resuelve `activities/01-select-menu-runbook/` siguiendo el README; valida con el script de tests.
5. Resuelve `activities/02-dialog-based-installer/`; prueba primero sin instalar `dialog` para forzar el fallback.
6. Lee `resources/links.md` y marca las dos manpages (`dialog(1)`, `read` en Bash manual) para consulta futura.

## Siguiente

→ `sys-18-arguments-functions-and-arrays`: parseo robusto de `--flags` con `getopts`, funciones con parámetros y arrays indexados/asociativos. Allí formalizamos el modo "flags" del dual-mode que aquí introducimos.
