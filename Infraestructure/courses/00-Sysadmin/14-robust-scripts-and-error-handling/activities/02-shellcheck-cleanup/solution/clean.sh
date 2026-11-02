#!/usr/bin/env bash
# clean.sh — resume el contenido de un directorio (versión limpia).
# Uso: clean.sh DIR
# Pasa shellcheck -S warning con 0 findings.
# Semántica externa equivalente al starter: imprime en stdout
#   total entries, files, dirs, biggest, y "<nombre> <tamaño>" por archivo regular.
set -euo pipefail
IFS=$'\n\t'

readonly EX_USAGE=64
readonly EX_NOINPUT=66

if (( $# != 1 )); then
    echo "uso: $(basename "$0") DIR" >&2
    exit "$EX_USAGE"
fi

dir=$1

if [[ ! -d "$dir" ]]; then
    echo "no es un directorio: $dir" >&2
    exit "$EX_NOINPUT"
fi

cd "$dir" || exit "$EX_NOINPUT"

# Contar entradas (incluyendo ocultos excluidos, igual que `ls` sin -a).
# Usamos un glob y contamos con parámetros posicionales en vez de parsear `ls`.
shopt -s nullglob
entries=( * )
total=${#entries[@]}
echo "total entries: $total"

files=0
dirs=0
for entry in "${entries[@]}"; do
    if [[ -f "$entry" ]]; then
        files=$((files + 1))
    elif [[ -d "$entry" ]]; then
        dirs=$((dirs + 1))
    fi
done
echo "files: $files"
echo "dirs: $dirs"

biggest() {
    # Separamos declaración y asignación para no tragar el exit code
    # del subcomando (SC2155).
    local max=""
    local best=-1
    local size entry
    for entry in "${entries[@]}"; do
        [[ -f "$entry" ]] || continue
        size=$(stat -c %s "$entry" 2>/dev/null || stat -f %z "$entry")
        if (( size > best )); then
            best=$size
            max=$entry
        fi
    done
    echo "biggest: $max"
}

biggest

for f in "${entries[@]}"; do
    if [[ -f "$f" ]]; then
        size=$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f")
        echo "$f $size"
    fi
done
