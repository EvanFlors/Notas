# Recursos — sys-21

## Documentación oficial de Bash

- **Bash Reference Manual — Shell Expansions** — <https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html> ★ lectura obligada
- **Bash Reference Manual — Shell Parameter Expansion** — <https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html>
- **Bash Reference Manual — Pattern Matching** — <https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html>
- **Bash Reference Manual — Redirections (incluye `<(…)` y `>(…)`)** — <https://www.gnu.org/software/bash/manual/html_node/Redirections.html>
- **Bash Reference Manual — The Shopt Builtin** — <https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html>
- **Bash Reference Manual — Coprocesses** — <https://www.gnu.org/software/bash/manual/html_node/Coprocesses.html>
- **Bash Reference Manual — Bash Variables (`BASH_SOURCE`, `BASH_LINENO`, `FUNCNAME`, …)** — <https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html>
- **Bash Reference Manual — The Set Builtin (`-euo pipefail`)** — <https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html>

## Manpages del sistema

- **`bash(1)`** — <https://man7.org/linux/man-pages/man1/bash.1.html>
- **`shopt(1)` builtin (sección de `bash(1)`)** — <https://man7.org/linux/man-pages/man1/bash.1.html#SHELL_BUILTIN_COMMANDS>
- **`mkfifo(1)`** — <https://man7.org/linux/man-pages/man1/mkfifo.1.html>
- **`mkfifo(3)`** — <https://man7.org/linux/man-pages/man3/mkfifo.3.html>
- **`fifo(7)`** (semántica de named pipes) — <https://man7.org/linux/man-pages/man7/fifo.7.html>
- **`dash(1)`** (para comparar con `/bin/sh` en Debian/Ubuntu) — <https://man7.org/linux/man-pages/man1/dash.1.html>

## Guías y referencias prácticas

- **Greg's Wiki — "Bash Guide"** — <https://mywiki.wooledge.org/BashGuide>
- **Greg's Wiki — "Bash Guide / Parameters / Expansions"** — <https://mywiki.wooledge.org/BashGuide/Parameters>
- **Greg's Wiki — "ProcessSubstitution"** — <https://mywiki.wooledge.org/ProcessSubstitution>
- **BashFAQ 024 — "I set variables in a loop that's in a pipeline. Why do they disappear after the loop terminates?"** — <https://mywiki.wooledge.org/BashFAQ/024> (motiva el patrón `while … done < <(…)`)
- **BashFAQ 073 — "How can I use parameter expansion?"** — <https://mywiki.wooledge.org/BashFAQ/073>
- **BashPitfalls** — <https://mywiki.wooledge.org/BashPitfalls>

## Portabilidad

- **POSIX Shell Command Language** (base común de `sh`) — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html>
- **"Rich's sh (POSIX shell) tricks"** — <http://www.etalabs.net/sh_tricks.html>
- **shellcheck wiki — modo `-s sh`** — <https://www.shellcheck.net/wiki/>

## Complementario

- **Google Shell Style Guide** — <https://google.github.io/styleguide/shellguide.html>
- **"Advanced Bash-Scripting Guide" (Mendel Cooper)** — <https://tldp.org/LDP/abs/html/> (clásico; vigila fecha, hay partes anticuadas, pero el capítulo de redirecciones y expansiones sigue siendo útil).

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los dominios son oficiales (`gnu.org`, `man7.org`, `pubs.opengroup.org`, `shellcheck.net`, `mywiki.wooledge.org`, `tldp.org`).
