#!/usr/bin/env bash
# Walkthrough del orden de expansión de Bash.
# Imprime qué queda después de cada etapa aplicada a una misma línea cruda.

set -euo pipefail
IFS=$'\n\t'

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/a" "$workdir/b"
: > "$workdir/a/one.txt"
: > "$workdir/a/two.txt"
: > "$workdir/b/three.txt"

cd "$workdir"

say() { printf '\n== %s ==\n' "$1"; }

say "Árbol inicial"
find . -type f | sort

say "0. Línea cruda"
printf '  echo {a,b}/*.txt > >(tee out.log) 2>&1\n'

say "1. Tras brace expansion (simulada con eval 'echo'):"
# Brace es puramente léxica: eval sobre echo nos deja ver qué produce.
# shellcheck disable=SC2086 # queremos ver el resultado sin quoting
set -- {a,b}/*.txt
printf '  tokens: %s\n' "$*"

say "2. Tras tilde expansion: nada que expandir aquí."

say "3. Tras param/arith/cmd subst: nada; la process substitution >(tee out.log)"
printf '  se materializa aquí como una ruta tipo /dev/fd/N.\n'

say "4. Tras word splitting: nada que splittear (no hay subst sin comillas con espacios)."

say "5. Tras pathname expansion (globbing):"
# Ya expandido por el shell en el 'set --' de arriba; esto es sólo para enfatizar.
for t in "$@"; do
  printf '  → %s\n' "$t"
done

say "6. Ejecución real de la línea completa"
echo {a,b}/*.txt > >(tee out.log) 2>&1
# El hijo >(tee ...) se ejecuta en background; esperamos un instante a que
# cierre antes de leer out.log. En scripts serios: usar un pipe directo o wait.
sleep 0.2
printf '\nout.log contiene: '
cat out.log

say "Variante: ¿qué pasa sin matches y sin nullglob?"
# shellcheck disable=SC2206 # queremos ver literal
tokens=( *.md )
printf '  tokens (sin nullglob): %s\n' "${tokens[*]}"

shopt -s nullglob
tokens=( *.md )
printf '  tokens (con nullglob): "%s" (vacío)\n' "${tokens[*]-}"
shopt -u nullglob
