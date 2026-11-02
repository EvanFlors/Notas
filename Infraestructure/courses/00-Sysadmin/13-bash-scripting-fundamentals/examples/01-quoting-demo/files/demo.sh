#!/usr/bin/env bash
#
# demo.sh — muestra cómo quoting cambia el resultado de los mismos comandos.

set -euo pipefail

name="informe final"
glob_pattern="*.sh"

printf '\n== 1. Sin comillas (word splitting activo) ==\n'
# shellcheck disable=SC2086
printf 'Argumentos recibidos por printf: '
# shellcheck disable=SC2086
printf '[%s] ' $name
printf '\n(La variable con espacio se dividió en DOS argumentos.)\n'

printf '\n== 2. Comillas simples (literal, sin expansion) ==\n'
printf '%s\n' '$name no se expande entre simples'
printf '%s\n' '$HOME tampoco'

printf '\n== 3. Comillas dobles (expande, NO divide) ==\n'
printf '[%s]\n' "$name"
printf '%s\n' "HOME = $HOME"

printf '\n== 4. Glob SIN comillas (expansion de pathname) ==\n'
cd /tmp
: > /tmp/quoting-demo-a.sh
: > /tmp/quoting-demo-b.sh
# shellcheck disable=SC2086
printf '  match: %s\n' /tmp/quoting-demo-*.sh

printf '\n== 5. Glob entre comillas (literal) ==\n'
printf '  literal: %s\n' "/tmp/quoting-demo-*.sh"

printf '\n== 6. Interpolacion con llaves ==\n'
prefix="log"
suffix="2026"
printf '%s\n' "${prefix}_backup_${suffix}.txt"

printf '\n== Limpieza ==\n'
rm -f /tmp/quoting-demo-a.sh /tmp/quoting-demo-b.sh
printf 'Hecho.\n'
