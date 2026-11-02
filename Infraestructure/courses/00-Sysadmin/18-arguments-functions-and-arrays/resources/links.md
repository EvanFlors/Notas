# sys-18 — Recursos

## Manual oficial de Bash

- **Positional Parameters** — `$0`, `$1..$N`, `$#`, `$@`, `$*`, `shift`.
  https://www.gnu.org/software/bash/manual/html_node/Positional-Parameters.html

- **Shell Parameter Expansion** — forma canónica de `${var}`, defaults (`${x:-}`), slicing.
  https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html

- **Arrays** — indexados y asociativos (`declare -a`, `declare -A`), iteración, `${!arr[@]}`.
  https://www.gnu.org/software/bash/manual/html_node/Arrays.html

- **Shell Functions** — sintaxis, scope, `local`, `return`.
  https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html

- **Bourne Shell Builtins → `getopts`** — opciones cortas, silent mode, `OPTIND`, `OPTARG`.
  https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-getopts

- **Bash Builtins → `declare` / `local` / `typeset`** — banderas (`-r`, `-i`, `-a`, `-A`, `-n`).
  https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html

## FAQs y guías de referencia

- **BashFAQ 035 — "How do I handle command-line arguments?"** — comparación de `getopts`, `getopt` GNU y parsing manual con `case`.
  https://mywiki.wooledge.org/BashFAQ/035

- **BashFAQ 005 — "How can I use variable variables?"** — por qué nameref (`declare -n`) es preferible a `eval`.
  https://mywiki.wooledge.org/BashFAQ/006

- **Bash Pitfalls** — colección de errores idiomáticos; especial atención a #1 (`for i in $(ls)`), #35 (`$@` sin comillas), #43 (`local`).
  https://mywiki.wooledge.org/BashPitfalls

- **util-linux `getopt(1)`** — manpage del `getopt` externo (necesario para opciones largas).
  https://man7.org/linux/man-pages/man1/getopt.1.html

## Herramientas

- **ShellCheck** — linter obligatorio para scripts no triviales. Detecta la mayoría de los problemas de este módulo (expansión sin comillas, `OPTIND` sin reset, uso de `$@` incorrecto).
  https://www.shellcheck.net/

- **shfmt** — formateador oficioso para Bash. Útil para dejar un estilo consistente antes de hacer PR.
  https://github.com/mvdan/sh

## Lectura complementaria

- **Google Shell Style Guide** — convenciones de nombres, funciones y uso de `local`.
  https://google.github.io/styleguide/shellguide.html

- **"Why `set -euo pipefail` is not enough"** — contexto sobre cuándo las banderas estrictas fallan y cómo complementarlas con `trap ERR`.
  https://mywiki.wooledge.org/BashFAQ/105
