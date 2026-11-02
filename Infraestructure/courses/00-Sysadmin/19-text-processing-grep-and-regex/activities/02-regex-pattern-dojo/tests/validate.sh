#!/usr/bin/env bash
# validate.sh — ejecuta cada REGEX_<CLASE> contra positivos y negativos
# del dataset. Falla si cualquier clase no es 100% correcta.
#
# Usage: bash tests/validate.sh [path/to/patterns.sh]

set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
PATTERNS="${1:-${ROOT}/starter/patterns.sh}"
DATASET="${ROOT}/starter/dataset.txt"
fail=0

echo "== Validando ${PATTERNS} =="

if [[ ! -f "${PATTERNS}" ]]; then
  echo "FAIL: no existe ${PATTERNS}"
  exit 1
fi
if [[ ! -f "${DATASET}" ]]; then
  echo "FAIL: no existe el dataset ${DATASET}"
  exit 1
fi

# Shellcheck opcional
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "${PATTERNS}"; then
    echo "  OK   shellcheck limpio"
  else
    echo "  FAIL shellcheck reporto issues"
    fail=$((fail+1))
  fi
fi

# Cargamos las variables del alumno. Si el archivo tiene errores de sintaxis,
# source falla y abortamos limpiamente.
# shellcheck disable=SC1090
if ! source "${PATTERNS}"; then
  echo "FAIL: no se pudo cargar ${PATTERNS} (errores de sintaxis bash?)"
  exit 1
fi

CLASSES=(IPV4 EMAIL ISODATE UUID BASHVAR URL HEXCOLOR)

# Dado un engine ('E' o 'P') y una regex, devuelve 0 si el string matchea,
# 1 si no, 2 si engine invalido o grep -P no disponible.
match_string() {
  local engine="$1" regex="$2" s="$3"
  case "${engine}" in
    E) printf '%s\n' "${s}" | grep -Eq -- "${regex}" ;;
    P)
      if ! grep -P '.' <<<"x" >/dev/null 2>&1; then
        return 2
      fi
      printf '%s\n' "${s}" | grep -Pq -- "${regex}"
      ;;
    *) return 2 ;;
  esac
}

for cls in "${CLASSES[@]}"; do
  regex_var="REGEX_${cls}"
  engine_var="ENGINE_${cls}"
  regex="${!regex_var:-}"
  engine="${!engine_var:-}"

  if [[ -z "${regex}" ]]; then
    echo "  FAIL [${cls}] REGEX vacia"
    fail=$((fail+1))
    continue
  fi

  # Debe estar anclada
  if [[ "${regex}" != ^* || "${regex}" != *\$ ]]; then
    echo "  FAIL [${cls}] la regex no esta anclada con ^...\$ : ${regex}"
    fail=$((fail+1))
    continue
  fi

  # Si el engine es P y grep -P no esta, saltamos la clase con nota
  if [[ "${engine}" == "P" ]] && ! grep -P '.' <<<"x" >/dev/null 2>&1; then
    echo "  SKIP [${cls}] grep -P no disponible en este sistema"
    continue
  fi

  pos_total=0; pos_ok=0
  neg_total=0; neg_ok=0

  # Iterar sobre el dataset para esa clase
  while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    tag="${line%% *}"       # p. ej. "IPV4+" o "IPV4-"
    val="${line#* }"
    class="${tag%?}"
    sign="${tag: -1}"
    [[ "${class}" != "${cls}" ]] && continue

    if [[ "${sign}" == "+" ]]; then
      pos_total=$((pos_total+1))
      if match_string "${engine}" "${regex}" "${val}"; then
        pos_ok=$((pos_ok+1))
      else
        echo "    - [${cls}] POSITIVO rechazado: '${val}'"
      fi
    elif [[ "${sign}" == "-" ]]; then
      neg_total=$((neg_total+1))
      rc=0
      match_string "${engine}" "${regex}" "${val}" || rc=$?
      if [[ "${rc}" -eq 2 ]]; then
        echo "    ! [${cls}] grep -${engine} no disponible, salto"
        continue 2
      fi
      if [[ "${rc}" -ne 0 ]]; then
        neg_ok=$((neg_ok+1))
      else
        echo "    - [${cls}] NEGATIVO aceptado: '${val}'"
      fi
    fi
  done < "${DATASET}"

  if [[ "${pos_ok}" -eq "${pos_total}" && "${neg_ok}" -eq "${neg_total}" && "${pos_total}" -gt 0 ]]; then
    echo "  OK   [${cls}] positivos ${pos_ok}/${pos_total}, negativos ${neg_ok}/${neg_total}"
  else
    echo "  FAIL [${cls}] positivos ${pos_ok}/${pos_total}, negativos ${neg_ok}/${neg_total}"
    fail=$((fail+1))
  fi
done

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULTADO: ${fail} clase(s) con errores."
  exit 1
fi
echo "OK: las 7 clases pasan 100% positivos y negativos."
exit 0
