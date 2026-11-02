#!/usr/bin/env bash
# report.sh — lee CSV host,load, calcula sum/avg/min/max y clasifica cada fila.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_csv="$here/../starter/data.csv"
csv="${1:-$default_csv}"

if [[ ! -r "$csv" ]]; then
  echo "FAIL: no se puede leer el CSV: $csv" >&2
  exit 1
fi

classify() {
  local load="$1"
  case "$load" in
    [0-9]|1[0-9])              echo "idle" ;;
    [2-5][0-9])                echo "normal" ;;
    [6-7][0-9]|8[0-4])         echo "busy" ;;
    8[5-9]|9[0-9]|100)         echo "critical" ;;
    *)                         echo "unknown" ;;
  esac
}

sum=0
count=0
min=""
max=""

printf '%-10s  %4s  %s\n' "host" "load" "class"

first=1
while IFS=',' read -r host load; do
  if (( first )); then
    first=0
    continue
  fi
  [[ -z "${host:-}" ]] && continue
  if ! [[ "$load" =~ ^[0-9]+$ ]]; then
    echo "WARN: load no numérica en host=$host load=$load" >&2
    continue
  fi
  if (( load < 0 || load > 100 )); then
    echo "WARN: load fuera de rango en host=$host load=$load" >&2
    continue
  fi

  class="$(classify "$load")"
  printf '%-10s  %4d  %s\n' "$host" "$load" "$class"

  sum=$((sum + load))
  count=$((count + 1))
  if [[ -z "$min" ]] || (( load < min )); then min="$load"; fi
  if [[ -z "$max" ]] || (( load > max )); then max="$load"; fi
done < "$csv"

if (( count == 0 )); then
  echo "FAIL: sin filas válidas" >&2
  exit 1
fi

avg=$(echo "scale=2; $sum / $count" | bc -l)
echo
echo "sum=$sum  avg=$avg  min=$min  max=$max"
