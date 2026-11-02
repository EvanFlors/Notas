#!/usr/bin/env bash
# demo.sh — group-by, suma y promedio con awk sobre un CSV.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV="${HERE}/sales.csv"

if [[ ! -f "${CSV}" ]]; then
  echo "ERROR: no se encuentra ${CSV}" >&2
  exit 2
fi

export LC_ALL=C  # orden y printf deterministas

banner() {
  echo
  echo "=============================================================="
  echo "  $*"
  echo "=============================================================="
}

banner "Dataset"
column -s, -t "${CSV}" 2>/dev/null || cat "${CSV}"

# -------------------------------------------------------------------
banner "1) Total facturado por region (sum)"

awk -F, '
  NR > 1 { total[$1] += $4 }
  END {
    for (r in total) printf "%-8s %10.2f\n", r, total[r]
  }
' "${CSV}" | sort -k2 -rn

# -------------------------------------------------------------------
banner "2) Unidades vendidas por producto (sum, desc)"

awk -F, '
  NR > 1 { units[$2] += $3 }
  END {
    for (p in units) printf "%-8s %6d\n", p, units[p]
  }
' "${CSV}" | sort -k2 -rn

# -------------------------------------------------------------------
banner "3) Ticket medio por region (sum / count)"

awk -F, '
  NR > 1 {
    total[$1] += $4
    count[$1] += 1
  }
  END {
    for (r in total)
      printf "%-8s avg=%7.2f  (n=%d)\n", r, total[r] / count[r], count[r]
  }
' "${CSV}" | sort

echo
echo "Observa: una pasada por el archivo (streaming), memoria O(regiones)."
