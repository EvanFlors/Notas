#!/usr/bin/env bash
#
# greet.sh — imprime un saludo parametrizado con firma obligatoria.
#
# Uso:
#   greet.sh [nombre] [saludo] <firma>
#
# Defaults:
#   nombre = "mundo"
#   saludo = "Hola"

set -euo pipefail

name="${1:-mundo}"
greeting="${2:-Hola}"
signature="${3:?Uso: $0 [nombre] [saludo] <firma>}"

printf '%s %s\n' "$greeting" "$name"
printf -- '-- %s\n' "$signature"
