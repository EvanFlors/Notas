#!/usr/bin/env bash
# Validacion estructural para sys-03-01-fhs-treasure-hunt.
# Chequea que el fichero de respuestas existe y cumple los minimos de forma.
# NO evalua correccion semantica — compara con solution/answers.md.

set -o pipefail
IFS=$'\n\t'

FILE="${1:-/tmp/fhs-answers.md}"
fail=0

echo "== Validacion estructural para ${FILE} =="

if [ ! -f "${FILE}" ]; then
    echo "FAIL: ${FILE} no existe. Copia starter/questions.md y responde."
    exit 1
fi

# Las 15 preguntas presentes como encabezados "### N."
answers_found=0
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if grep -Eq "^### ${n}\\." "${FILE}"; then
        answers_found=$((answers_found + 1))
    fi
done

if [ "${answers_found}" -ge 15 ]; then
    echo "  OK   15 preguntas presentes como encabezados"
else
    echo "  FAIL solo ${answers_found}/15 preguntas presentes"
    fail=$((fail + 1))
fi

# Debe mencionar rutas canonicas del FHS
required_paths=(
    "/etc"
    "/var/log"
    "/usr/local"
    "/opt"
    "/proc"
    "/sys"
    "/run"
)
for p in "${required_paths[@]}"; do
    if grep -Fq "${p}" "${FILE}"; then
        echo "  OK   menciona ${p}"
    else
        echo "  FAIL no menciona ${p}"
        fail=$((fail + 1))
    fi
done

# Comandos esperados en al menos algunas respuestas
command_hits=0
for cmd in "stat" "readlink" "find" "ls -l" "mount" "findmnt"; do
    if grep -Fq "${cmd}" "${FILE}"; then
        command_hits=$((command_hits + 1))
    fi
done
if [ "${command_hits}" -ge 3 ]; then
    echo "  OK   usa al menos 3 comandos de inspeccion esperados (${command_hits}/6)"
else
    echo "  FAIL solo ${command_hits}/6 comandos de inspeccion mencionados"
    fail=$((fail + 1))
fi

# La respuesta 5 NO debe recomendar /usr/bin para binarios propios
if awk '/^### 5\./,/^### 6\./' "${FILE}" | grep -Eq '/usr/bin($|[^/-])'; then
    echo "  FAIL respuesta 5 menciona /usr/bin para binario propio (debe ser /usr/local/bin o ~/.local/bin)"
    fail=$((fail + 1))
else
    echo "  OK   respuesta 5 no recomienda /usr/bin"
fi

# La respuesta 15 debe usar -print0 y -xdev
block15=$(awk '/^### 15\./,0' "${FILE}")
if printf '%s\n' "${block15}" | grep -q -- "-print0"; then
    echo "  OK   respuesta 15 usa -print0"
else
    echo "  FAIL respuesta 15 no usa -print0 (nombres hostiles romperian)"
    fail=$((fail + 1))
fi
if printf '%s\n' "${block15}" | grep -q -- "-xdev"; then
    echo "  OK   respuesta 15 usa -xdev"
else
    echo "  FAIL respuesta 15 no usa -xdev (puede cruzar mounts)"
    fail=$((fail + 1))
fi

echo
if [ "${fail}" -gt 0 ]; then
    echo "RESULT: ${fail} checks estructurales fallaron."
    echo "        Compara con solution/answers.md para evaluar la semantica."
    exit 1
fi

echo "OK: estructura valida. Compara con solution/answers.md para autoevaluarte."
exit 0
