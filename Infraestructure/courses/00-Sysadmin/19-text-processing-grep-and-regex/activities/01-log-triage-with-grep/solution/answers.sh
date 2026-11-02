#!/usr/bin/env bash
# answers.sh — SOLUCION de la actividad sys-19-01-log-triage-with-grep.
# Hay mas de una forma correcta de responder cada pregunta; esta es una
# version idiomatica, no "la unica".

set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# El solucionario vive en solution/, el log en starter/.
LOG="${LOG:-${HERE}/../starter/access.log}"

if [[ ! -f "${LOG}" ]]; then
  echo "ERROR: no se encuentra ${LOG}" >&2
  exit 2
fi

q1() {
  echo "--- Q1 ---"
  wc -l < "${LOG}"
}

q2() {
  echo "--- Q2 ---"
  # El metodo HTTP es la primera palabra dentro de las primeras comillas.
  awk -F'"' '{split($2, a, " "); print a[1]}' "${LOG}" \
    | sort | uniq -c | sort -rn
}

q3() {
  echo "--- Q3 ---"
  # El status es $9 cuando partimos por espacios (campo tras el HTTP/1.1").
  awk '{print $9}' "${LOG}" | sort | uniq -c | sort -rn
}

q4() {
  echo "--- Q4 ---"
  awk '{print $1}' "${LOG}" | sort | uniq -c | sort -rn | head -10
}

q5() {
  echo "--- Q5 ---"
  awk '$9 ~ /^5/ {print $7}' "${LOG}" \
    | sort | uniq -c | sort -rn | head -10
}

q6() {
  echo "--- Q6 ---"
  # user-agent es el 6o campo cuando partimos por comillas:
  # <ip ...>" METHOD PATH HTTP/1.1 " STATUS BYTES " REFERRER " USER_AGENT "
  # Indices: $1 pre, $2 req, $3 mid, $4 referrer, $5 mid2, $6 user-agent.
  awk -F'"' '{print $6}' "${LOG}" | sort | uniq -c \
    | awk '$1 > 50' | sort -rn
}

q7() {
  echo "--- Q7 ---"
  # IPs cuyos status unicos sean exactamente {403}.
  awk '{print $1, $9}' "${LOG}" | sort -u \
    | awk '{seen[$1]++; last[$1]=$2}
           END {for (ip in seen) if (seen[ip]==1 && last[ip]=="403") print ip}' \
    | sort
}

q8() {
  echo "--- Q8 ---"
  # El timestamp es $4 = "[12/May/2026:14:03:11". La hora son los
  # caracteres 14-15 (1-indexado): dd/mmm/YYYY:HH
  awk '$9 ~ /^5/ {print substr($4, 14, 2)}' "${LOG}" \
    | sort | uniq -c | sort -rn | head -1
}

q9() {
  echo "--- Q9 ---"
  awk '
    $7 ~ /^\/api\/v1\// {
      total++
      if ($9 ~ /^[45]/) err++
    }
    END {
      if (total > 0)
        printf "total=%d errors=%d rate=%.2f%%\n", total, err+0, (err+0)/total*100
      else
        print "total=0"
    }
  ' "${LOG}"
}

q10() {
  echo "--- Q10 ---"
  # grep -oE extrae solo la parte matcheada; cortamos antes de ? si hay.
  grep -oE '/api/v1/users/[^ ?"]*' "${LOG}" | sort -u
}

main() {
  q1; q2; q3; q4; q5; q6; q7; q8; q9; q10
}

main "$@"
