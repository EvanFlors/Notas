# Recursos — sys-14

## Documentación oficial

- **Bash Reference Manual — `set` builtin** — <https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html>
- **Bash Reference Manual — `trap` y señales** — <https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-trap>
- **Bash Reference Manual — Exit Status** — <https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html>
- **`flock(1)` (util-linux)** — <https://man7.org/linux/man-pages/man1/flock.1.html>
- **`flock(2)` (syscall)** — <https://man7.org/linux/man-pages/man2/flock.2.html>
- **`signal(7)`** — <https://man7.org/linux/man-pages/man7/signal.7.html>
- **`sysexits.h`** (FreeBSD, convención 64–78) — <https://man.freebsd.org/cgi/man.cgi?sysexits(3)>

## Trampas y referencia práctica

- **BashFAQ 105 — "Why doesn't `set -e` (or `set -o errexit`, or `trap ERR`) do what I expected?"** — <https://mywiki.wooledge.org/BashFAQ/105> ★ lectura obligada
- **BashFAQ 112 — "What are the advantages and disadvantages of using `set -u`?"** — <https://mywiki.wooledge.org/BashFAQ/112>
- **BashPitfalls** (lista mantenida de trampas comunes) — <https://mywiki.wooledge.org/BashPitfalls>
- **Greg's Wiki — "Bash Guide"** — <https://mywiki.wooledge.org/BashGuide>

## shellcheck

- **shellcheck — sitio** — <https://www.shellcheck.net/>
- **shellcheck — wiki de códigos** — <https://www.shellcheck.net/wiki/>
- **shellcheck — repositorio** — <https://github.com/koalaman/shellcheck>
- Códigos frecuentes a reconocer: `SC2086` (quoting), `SC2155` (declare y assign en una línea), `SC2164` (`cd` sin `|| exit`), `SC2181` (`$?` en vez de chequear directo), `SC1091` (source de archivo no visible), `SC2034` (variable asignada y no usada).

## Complementario

- **"Writing shell scripts" — Google Shell Style Guide** — <https://google.github.io/styleguide/shellguide.html>
- **"Defensive BASH programming"** (Kfir Lavi) — <https://kfirlavi.herokuapp.com/blog/2012/11/14/defensive-bash-programming/> (clásico; algunos consejos envejecen mejor que otros, lee con criterio).
- **"Rich’s sh (POSIX shell) tricks"** — <http://www.etalabs.net/sh_tricks.html>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces son dominios oficiales (`gnu.org`, `man7.org`, `freebsd.org`, `shellcheck.net`, `mywiki.wooledge.org`); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
