#!/usr/bin/env bash
# find-biggest.sh — imprime los N archivos regulares mas grandes bajo DIR.
# Robusto ante nombres hostiles (espacios, newlines, guiones iniciales, unicode).
# No cruza mount points.
#
# Uso: find-biggest.sh DIR [N]
set -euo pipefail
IFS=$'\n\t'

usage() {
    cat <<'EOF' >&2
Uso: find-biggest.sh DIR [N]
    DIR  directorio raiz donde buscar
    N    cuantos archivos imprimir (default 10)
EOF
    exit 2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

DIR="$1"
N="${2:-10}"

# Validaciones minimas
if [ ! -d "${DIR}" ]; then
    echo "ERROR: '${DIR}' no es un directorio" >&2
    exit 1
fi
if ! [[ "${N}" =~ ^[0-9]+$ ]] || [ "${N}" -lt 1 ]; then
    echo "ERROR: N debe ser entero positivo (recibi '${N}')" >&2
    exit 1
fi

# Estrategia:
#   find con -print0 (separador NUL)
#   xargs -0 pasa los nombres a stat correctamente
#   stat --printf '%s\t%n\n' da "<bytes>\t<ruta>"
#   sort -rn ordena por bytes descendente
#   head -n N recorta.
# Alternativa equivalente: find ... -exec stat --printf='%s\t%n\n' -- {} +
find "${DIR}" -xdev -type f -print0 \
    | xargs -0 -r -- stat --printf='%s\t%n\n' -- \
    | sort -rn \
    | head -n "${N}"
