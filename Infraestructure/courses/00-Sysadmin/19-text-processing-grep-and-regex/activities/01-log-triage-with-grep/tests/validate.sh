#!/usr/bin/env bash
# validate.sh — structural + spot-check validation for sys-19-01.
# Usage:  bash tests/validate.sh [path/to/answers.sh]

set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
ANSWERS="${1:-${ROOT}/starter/answers.sh}"
LOG="${ROOT}/starter/access.log"
fail=0

echo "== Validando ${ANSWERS} =="

# --- 0) Preexistencias --------------------------------------------------
if [[ ! -f "${ANSWERS}" ]]; then
  echo "FAIL: no existe ${ANSWERS}"
  exit 1
fi
if [[ ! -f "${LOG}" ]]; then
  echo "FAIL: no existe el dataset ${LOG}"
  exit 1
fi

# --- 1) Shellcheck opcional --------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "${ANSWERS}"; then
    echo "  OK   shellcheck limpio"
  else
    echo "  FAIL shellcheck reporto issues"
    fail=$((fail+1))
  fi
else
  echo "  SKIP shellcheck no instalado"
fi

# --- 2) Ejecucion -------------------------------------------------------
OUT="$(mktemp)"
trap 'rm -f "${OUT}"' EXIT
if LOG="${LOG}" bash "${ANSWERS}" >"${OUT}" 2>&1; then
  echo "  OK   el script corre sin error"
else
  echo "  FAIL el script fallo al ejecutar. Salida parcial:"
  sed 's/^/    | /' "${OUT}" | head -20
  exit 1
fi

# --- 3) Encabezados Q1..Q10 presentes ----------------------------------
for n in 1 2 3 4 5 6 7 8 9 10; do
  if grep -q "^--- Q${n} ---$" "${OUT}"; then
    echo "  OK   contiene encabezado Q${n}"
  else
    echo "  FAIL falta encabezado --- Q${n} ---"
    fail=$((fail+1))
  fi
done

# --- 4) Spot checks numericos ------------------------------------------
# Q1 total 1200
section() {
  # Imprime desde "--- Q$1 ---" (exclusivo) hasta el proximo "--- Q" o EOF.
  awk -v s="--- Q$1 ---" '
    $0 == s {inside=1; next}
    inside && /^--- Q/ {exit}
    inside {print}
  ' "${OUT}"
}

q1="$(section 1 | tr -d ' \t' | head -1)"
if [[ "${q1}" == "1200" ]]; then
  echo "  OK   Q1 reporta 1200 peticiones"
else
  echo "  FAIL Q1 esperaba 1200, encontre '${q1}'"
  fail=$((fail+1))
fi

# Q3 debe contener 200 798 (en algun orden razonable)
if section 3 | grep -Eq '(^|[^0-9])798([^0-9]|$)' && \
   section 3 | grep -Eq '(^|[^0-9])200([^0-9]|$)'; then
  echo "  OK   Q3 incluye el 798 x status 200"
else
  echo "  FAIL Q3 no muestra 798 para status 200"
  fail=$((fail+1))
fi

# Q4 top IP esperado 203.0.113.5 o 203.0.113.2 con 100
if section 4 | head -1 | grep -Eq '\b100\b.*203\.0\.113\.(2|5)\b'; then
  echo "  OK   Q4 top IP es 203.0.113.{2,5} con 100 hits"
else
  echo "  FAIL Q4 no reporta top IP esperado"
  fail=$((fail+1))
fi

# Q7 debe incluir las 3 IPs 403-only y nada mas
expected_403=("10.0.0.42" "10.0.0.99" "172.16.3.7")
got_403="$(section 7 | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)"
missing=0
for ip in "${expected_403[@]}"; do
  if ! grep -qx "${ip}" <<<"${got_403}"; then
    echo "  FAIL Q7 no lista IP esperada: ${ip}"
    missing=1
  fi
done
extra="$(comm -23 <(echo "${got_403}") <(printf '%s\n' "${expected_403[@]}" | sort))"
if [[ -n "${extra}" ]]; then
  echo "  FAIL Q7 lista IPs no esperadas:"
  echo "${extra}" | sed 's/^/        /'
  missing=1
fi
if [[ "${missing}" -eq 0 ]]; then
  echo "  OK   Q7 lista exactamente las 3 IPs 403-only"
else
  fail=$((fail+1))
fi

# Q8 hora pico de 5xx = 14 (del dataset generado)
if section 8 | grep -Eq '(^|[^0-9])14([^0-9]|$)'; then
  echo "  OK   Q8 identifica la hora 14 como pico de 5xx"
else
  echo "  FAIL Q8 no identifica la hora 14"
  fail=$((fail+1))
fi

# Q10 debe contener al menos 5 rutas /api/v1/users
n_users="$(section 10 | grep -cE '^/api/v1/users')"
if [[ "${n_users}" -ge 5 ]]; then
  echo "  OK   Q10 lista ${n_users} rutas bajo /api/v1/users/"
else
  echo "  FAIL Q10 lista solo ${n_users} rutas (esperado >= 5)"
  fail=$((fail+1))
fi

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULTADO: ${fail} chequeos fallaron."
  exit 1
fi
echo "OK: validacion estructural y spot-checks superados."
exit 0
