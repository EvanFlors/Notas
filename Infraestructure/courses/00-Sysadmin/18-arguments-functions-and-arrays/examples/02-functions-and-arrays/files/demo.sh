#!/usr/bin/env bash
#
# demo.sh — Funciones y arrays (sys-18 ejemplo 02)
#
set -euo pipefail
IFS=$'\n\t'

section() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Scope: variable global pisada por una función sin `local`
# ---------------------------------------------------------------------------
section "scope: con y sin local"

i="externa"

no_local() {
    for i in a b c; do :; done   # pisa la i global
}

con_local() {
    local i
    for i in a b c; do :; done   # scope aislado
}

no_local
printf 'sin local: i=%s   (se pisó)\n' "$i"

i="externa"
con_local
printf 'con local: i=%s   (preservada)\n' "$i"

# ---------------------------------------------------------------------------
# 2. Captura de salida: así se "devuelven" valores reales
# ---------------------------------------------------------------------------
section "captura con \$(func)"

sum() {
    local a=$1 b=$2
    echo $((a + b))        # salida a stdout, no `return`
}

result=$(sum 7 35)
printf 'sum(7, 35) = %s\n' "$result"

# ---------------------------------------------------------------------------
# 3. return solo acepta 0..255 (truncamiento mod 256)
# ---------------------------------------------------------------------------
section "return truncado a 0..255"

big_return() {
    return 300
}

# Deshabilitamos pipefail/errexit solo para capturar el código sin salir
set +e
big_return
rc=$?
set -e

printf 'return 300 -> \$?=%d  (300 mod 256 = 44)\n' "$rc"

# ---------------------------------------------------------------------------
# 4. Arrays indexados: longitud, iteración, slicing, append
# ---------------------------------------------------------------------------
section "arrays indexados"

declare -a frutas=(manzana pera "fruta del dragón" uva)

printf 'longitud: %d\n' "${#frutas[@]}"

printf 'iteración por valor:\n'
for f in "${frutas[@]}"; do
    printf '  - %s\n' "$f"
done

printf 'iteración por índice:\n'
for i in "${!frutas[@]}"; do
    printf '  [%d] %s\n' "$i" "${frutas[i]}"
done

printf 'slice [1:2]: %s\n' "${frutas[*]:1:2}"

frutas+=("sandía")
printf 'después de append: %d elementos\n' "${#frutas[@]}"

# ---------------------------------------------------------------------------
# 5. Arrays asociativos: claves string, iteración con ${!map[@]}
# ---------------------------------------------------------------------------
section "arrays asociativos"

declare -A env=(
    [HOST]="api.example.com"
    [PORT]="443"
    [SCHEME]="https"
    [TIMEOUT]="30"
)

printf 'claves (orden no garantizado):\n'
for k in "${!env[@]}"; do
    printf '  %-10s = %s\n' "$k" "${env[$k]}"
done

# ---------------------------------------------------------------------------
# 6. Nameref: modificar array del caller desde una función
# ---------------------------------------------------------------------------
section "nameref: push_unique"

push_unique() {
    local -n _arr=$1       # prefijo _ para evitar colisión con la global
    local value=$2
    local item
    for item in "${_arr[@]}"; do
        if [[ "$item" == "$value" ]]; then
            return 0        # ya existe
        fi
    done
    _arr+=("$value")
}

lista=(alpha beta)
printf 'antes:   %s\n' "${lista[*]}"

push_unique lista gamma
push_unique lista beta     # duplicado, no se añade

printf 'después: %s\n' "${lista[*]}"
