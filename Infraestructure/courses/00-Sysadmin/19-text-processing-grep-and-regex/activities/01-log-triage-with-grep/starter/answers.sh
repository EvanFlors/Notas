#!/usr/bin/env bash
# answers.sh — plantilla para la actividad sys-19-01-log-triage-with-grep.
# Rellena cada funcion q1..q10 con el pipeline correspondiente.
#
# Convencion: cada funcion imprime una linea "--- Q<n> ---" y luego el
# resultado. El validador busca esos encabezados.

set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${LOG:-${HERE}/access.log}"

if [[ ! -f "${LOG}" ]]; then
  echo "ERROR: no se encuentra ${LOG}" >&2
  exit 2
fi

q1() {
  echo "--- Q1 ---"
  # TODO: total de peticiones
  : "${LOG:?}"
}

q2() {
  echo "--- Q2 ---"
  # TODO: distribucion por metodo HTTP
  :
}

q3() {
  echo "--- Q3 ---"
  # TODO: distribucion por status code
  :
}

q4() {
  echo "--- Q4 ---"
  # TODO: top 10 IPs
  :
}

q5() {
  echo "--- Q5 ---"
  # TODO: top 10 URLs con 5xx
  :
}

q6() {
  echo "--- Q6 ---"
  # TODO: user-agents con > 50 peticiones
  :
}

q7() {
  echo "--- Q7 ---"
  # TODO: IPs que SOLO recibieron 403
  :
}

q8() {
  echo "--- Q8 ---"
  # TODO: hora del dia con mas 5xx
  :
}

q9() {
  echo "--- Q9 ---"
  # TODO: /api/v1/* total, errores (4xx+5xx), tasa
  :
}

q10() {
  echo "--- Q10 ---"
  # TODO: rutas unicas bajo /api/v1/users/
  :
}

main() {
  q1; q2; q3; q4; q5; q6; q7; q8; q9; q10
}

main "$@"
