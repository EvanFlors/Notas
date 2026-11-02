#!/usr/bin/env bash
# Validacion para sys-03-02-safe-find-xargs.
# Comprueba estructura y comportamiento del script find-biggest.sh.

set -o pipefail
IFS=$'\n\t'

SCRIPT="${1:-/tmp/messy/find-biggest.sh}"
DIR="${2:-/tmp/messy}"
fail=0

echo "== Validacion de ${SCRIPT} sobre ${DIR} =="

if [ ! -f "${SCRIPT}" ]; then
    echo "FAIL: ${SCRIPT} no existe"
    exit 1
fi
if [ ! -x "${SCRIPT}" ]; then
    echo "FAIL: ${SCRIPT} no es ejecutable (chmod +x)"
    exit 1
fi
if [ ! -d "${DIR}" ]; then
    echo "FAIL: ${DIR} no existe. Ejecuta starter/make-messy-files.sh primero."
    exit 1
fi

# Chequeos de forma
checks=(
    "#!/usr/bin/env bash"
    "set -euo pipefail"
    "IFS="
)
for c in "${checks[@]}"; do
    if grep -Fq "${c}" "${SCRIPT}"; then
        echo "  OK   contiene '${c}'"
    else
        echo "  FAIL falta '${c}'"
        fail=$((fail + 1))
    fi
done

# Debe usar -print0/-0 o -exec ... +
if grep -q -- "-print0" "${SCRIPT}" && grep -q -- "-0" "${SCRIPT}"; then
    echo "  OK   usa -print0 + xargs -0"
elif grep -Eq -- "-exec[[:space:]].+[[:space:]]\+" "${SCRIPT}"; then
    echo "  OK   usa -exec ... +"
else
    echo "  FAIL no usa -print0/-0 ni -exec ... +"
    fail=$((fail + 1))
fi

# Debe usar -xdev
if grep -q -- "-xdev" "${SCRIPT}"; then
    echo "  OK   usa -xdev (no cruza mounts)"
else
    echo "  FAIL no usa -xdev"
    fail=$((fail + 1))
fi

# shellcheck opcional
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "${SCRIPT}"; then
        echo "  OK   shellcheck limpio"
    else
        echo "  FAIL shellcheck encontro problemas"
        fail=$((fail + 1))
    fi
else
    echo "  SKIP shellcheck no instalado"
fi

# Ejecutar y chequear comportamiento
echo
echo "== Ejecutando: bash ${SCRIPT} ${DIR} 20 =="
out=$(bash "${SCRIPT}" "${DIR}" 20 2>/dev/null || true)
if [ -z "${out}" ]; then
    echo "FAIL: salida vacia; el script no imprimio nada"
    fail=$((fail + 1))
else
    printf '%s\n' "${out}" | head -5
fi

# Cuenta de archivos reales en DIR usando NUL safe
expected=$(find "${DIR}" -xdev -type f -print0 | tr -cd '\0' | wc -c | tr -d ' ')
got=$(printf '%s\n' "${out}" | grep -c . || true)
# El script pide los 20 mas grandes, debe devolver min(expected, 20)
want=$(( expected < 20 ? expected : 20 ))
if [ "${got}" -eq "${want}" ]; then
    echo "  OK   devuelve ${got} lineas (esperado ${want} = min(archivos=${expected}, N=20))"
else
    echo "  FAIL devuelve ${got} lineas (esperado ${want})"
    fail=$((fail + 1))
fi

# El archivo mas grande debe ser GRANDE.bin (50 KiB) segun el starter
first_line=$(printf '%s\n' "${out}" | head -1 || true)
if printf '%s' "${first_line}" | grep -Fq "GRANDE.bin"; then
    echo "  OK   el primero es GRANDE.bin"
else
    echo "  WARN primer archivo no es GRANDE.bin (puede ser esperado si cambiaste el starter)"
fi

# Comprueba que un nombre con newline aparece como UNA linea reportada
# (si el pipeline fuera inseguro, se partiria en 3 lineas)
if printf '%s' "${out}" | grep -Fq $'archivo\ncon\nnewline.txt'; then
    echo "  OK   nombre con newline embebido manejado como un solo archivo"
else
    echo "  WARN no se detecto el archivo con newline (verifica tu starter)"
fi

echo
if [ "${fail}" -gt 0 ]; then
    echo "RESULT: ${fail} checks fallaron."
    exit 1
fi
echo "OK: script find-biggest.sh es robusto."
exit 0
