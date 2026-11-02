#!/usr/bin/env bash
# Genera un directorio con nombres de archivo hostiles para probar que
# tu pipeline con find/xargs es robusto.
# Idempotente: borra y recrea el directorio.
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-/tmp/messy}"

echo "==> Reseteando ${DIR}"
rm -rf "${DIR}"
mkdir -p "${DIR}"
cd "${DIR}"

echo "==> Creando archivos con nombres hostiles"

# 1. Normal
printf 'A%.0s' {1..100} > normal.txt

# 2. Con espacios
printf 'B%.0s' {1..200} > "con espacios.txt"

# 3. Con comillas simples
printf 'C%.0s' {1..300} > "it's.txt"

# 4. Con newline embebido (sí, es legal)
nl_name=$'archivo\ncon\nnewline.txt'
printf 'D%.0s' {1..400} > "${nl_name}"

# 5. Guion inicial (parece una flag)
printf 'E%.0s' {1..500} > -- '-rf'

# 6. Unicode
printf 'F%.0s' {1..600} > "camión-año-€.txt"

# 7. Punto inicial (hidden)
printf 'G%.0s' {1..50} > .oculto

# 8. Nombre largo
long=$(printf 'x%.0s' {1..80})
printf 'H%.0s' {1..700} > "${long}.txt"

# 9. Subdirectorio con nombre con espacio
mkdir -p "sub dir"
printf 'I%.0s' {1..800} > "sub dir/anidado con espacio.txt"

# 10. Archivo grande (lo buscamos como top-1)
dd if=/dev/zero of="GRANDE.bin" bs=1024 count=50 status=none

echo
echo "==> Listado (con control chars escapados por ls):"
ls -la --quoting-style=escape "${DIR}" || ls -la "${DIR}"

echo
echo "==> Cuenta de archivos regulares reales:"
find "${DIR}" -type f -print0 | tr -cd '\0' | wc -c
echo "(numero de bytes NUL = numero de archivos)"

echo
echo "Done. Prueba tu pipeline sobre ${DIR}"
