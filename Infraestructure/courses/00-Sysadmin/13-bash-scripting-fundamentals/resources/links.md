# Recursos — sys-13 Bash scripting fundamentals

Referencias verificables para profundizar. Todas accedidas y vigentes a 2026-11.

## Manuales oficiales

- **GNU Bash Reference Manual — Quoting**
  https://www.gnu.org/software/bash/manual/html_node/Quoting.html
  Definicion canonica de comillas simples, dobles, backslash y `$'...'`. Lectura obligatoria si vas a escribir Bash profesionalmente.

- **GNU Bash Reference Manual — Shell Parameters**
  https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html
  Variables posicionales, especiales (`$@`, `$*`, `$#`, `$?`), scoping y la familia de expansiones `${var:-...}`, `${var:=...}`, `${var:?...}`, `${var:+...}`.

- **GNU Bash Reference Manual — Shell Parameter Expansion**
  https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
  Lista completa de expansiones: substring, length, pattern substitution (`${var/x/y}`), case modification, remove prefix/suffix.

- **POSIX.1-2017 — Shell Command Language**
  https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  Para scripts portables (`#!/bin/sh`). Delimita el subconjunto POSIX que corre en `dash`, `ash`, `ksh`, etc.

## Guia de estilo

- **Google Shell Style Guide**
  https://google.github.io/styleguide/shellguide.html
  Estandar informal del ecosistema. Reglas sobre shebang, indentacion, nombres de variables, uso de `[[` vs `[`, cuando usar funciones.

## Trampas comunes

- **mywiki.wooledge.org — BashPitfalls**
  https://mywiki.wooledge.org/BashPitfalls
  Lista mantenida de ~60 bugs tipicos de Bash con explicacion de por que ocurren y como arreglarlos. El mejor recurso unico de "lo que no sabias que no sabias".

- **mywiki.wooledge.org — BashGuide**
  https://mywiki.wooledge.org/BashGuide
  Guia pedagogica alternativa al manual oficial. Mas conversacional, misma profundidad.

- **mywiki.wooledge.org — Quotes**
  https://mywiki.wooledge.org/Quotes
  Pagina dedicada solo a quoting con ejemplos antes/despues.

## Herramientas

- **shellcheck**
  https://www.shellcheck.net/
  Linter indispensable. Pegalo online para pruebas rapidas; instalalo (`apt`/`brew`/`pacman`) para CI y editor. Cada warning tiene un codigo (`SCxxxx`) con pagina de documentacion propia explicando el bug.

- **shfmt**
  https://github.com/mvdan/sh
  Formateador consistente para Bash y POSIX sh. Complemento de `shellcheck`.

## Lectura ampliada

- **Robust Bash Scripts — Aaron Maxwell**
  https://aaronmaxwell.com/articles/robust-bash-scripting.html
  Breve, pragmatico. Resume `set -euo pipefail`, trap, locking.

- **"Bash Guide for Beginners" — Machtelt Garrels (TLDP)**
  https://tldp.org/LDP/Bash-Beginners-Guide/html/
  Larga pero gratis. Util para repasar fundamentos POSIX antes de pasar a Bash puro.
