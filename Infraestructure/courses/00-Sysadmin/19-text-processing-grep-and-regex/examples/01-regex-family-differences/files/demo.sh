#!/usr/bin/env bash
# demo.sh — misma intencion expresada en BRE, ERE y PCRE.
# Sin side effects: solo imprime a stdout.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="${HERE}/sample.txt"

if [[ ! -f "${SAMPLE}" ]]; then
  echo "ERROR: no se encuentra ${SAMPLE}" >&2
  exit 2
fi

banner() {
  echo
  echo "=============================================================="
  echo "  $*"
  echo "=============================================================="
}

run() {
  local label="$1"
  shift
  echo
  echo "--- ${label} ---"
  echo "\$ $*"
  # shellcheck disable=SC2068  # intentional word-split for display
  "$@" || true
}

# -------------------------------------------------------------------
banner "1) Palabras con 3 o mas vocales consecutivas"

# En BRE, '+' no es cuantificador; hay que usar \{3,\} o repeticion
# literal. Mostramos la version POSIX portable con \{3,\}.
run "BRE   (grep)"    grep    "[aeiou]\{3,\}" "${SAMPLE}"
run "ERE   (grep -E)" grep -E "[aeiou]{3,}"   "${SAMPLE}"
if grep -P '.' <<<"x" >/dev/null 2>&1; then
  run "PCRE  (grep -P)" grep -P "[aeiou]{3,}"   "${SAMPLE}"
else
  echo
  echo "--- PCRE  (grep -P) ---  SKIPPED: tu grep no soporta -P"
fi

# -------------------------------------------------------------------
banner "2) Palabra duplicada consecutiva (backreferences)"

# BRE: grupos con \(...\), referencia con \1
# ERE: grupos con (...), referencia con \1 igual
# PCRE: idem ERE, mismo \1
run "BRE"  grep    "\\<\\([[:alpha:]]\\+\\) \\1\\>" "${SAMPLE}"
run "ERE"  grep -E "\\<([[:alpha:]]+) \\1\\>"       "${SAMPLE}"
if grep -P '.' <<<"x" >/dev/null 2>&1; then
  run "PCRE" grep -P "\\b([[:alpha:]]+) \\1\\b"     "${SAMPLE}"
fi

# -------------------------------------------------------------------
banner "3) Email con dominio .com"

# El punto literal necesita escape en las tres familias cuando lo
# queremos como punto y no como "cualquier caracter".
run "BRE"  grep    "[[:alnum:]_.-]\\+@[[:alnum:].-]\\+\\.com$" "${SAMPLE}"
run "ERE"  grep -E "[[:alnum:]_.-]+@[[:alnum:].-]+\\.com$"      "${SAMPLE}"
if grep -P '.' <<<"x" >/dev/null 2>&1; then
  run "PCRE" grep -P "[\\w.-]+@[\\w.-]+\\.com$"                "${SAMPLE}"
fi

# -------------------------------------------------------------------
banner "4) Numero precedido por \$ sin consumirlo (lookbehind, solo PCRE)"

# En BRE/ERE no hay lookbehind; lo mas cercano es capturar \$([0-9]+)
# y luego cortar con sed/awk. En PCRE basta (?<=\$).
run "ERE  (sin lookbehind: captura y recorta con sed)" \
    bash -c "grep -oE '\\\$[0-9]+' '${SAMPLE}' | sed 's/^\\\$//'"
if grep -P '.' <<<"x" >/dev/null 2>&1; then
  run "PCRE (con lookbehind)" grep -oP "(?<=\\\$)[0-9]+" "${SAMPLE}"
else
  echo "--- PCRE ---  SKIPPED"
fi

echo
echo "=============================================================="
echo "  FIN. Observa: BRE y ERE producen lo MISMO. PCRE agrega una"
echo "  capacidad (lookbehind) que las otras dos no tienen."
echo "=============================================================="
