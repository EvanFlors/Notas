#!/usr/bin/env bash
# validate.sh — valida el script report.sh del estudiante contra data.csv.
# Uso: bash tests/validate.sh [ruta_al_script]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
script="${1:-$root/report.sh}"
csv="$root/starter/data.csv"
fail=0

echo "== Validando: $script =="

if [[ ! -f "$script" ]]; then
  echo "  FAIL  no existe el script: $script"
  exit 1
fi
if [[ ! -r "$csv" ]]; then
  echo "  FAIL  no se puede leer el CSV de referencia: $csv"
  exit 1
fi

# shellcheck opcional
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$script" >/tmp/sys15-shellcheck.$$ 2>&1; then
    echo "  OK    shellcheck limpio"
  else
    echo "  FAIL  shellcheck reportó avisos:"
    sed 's/^/        /' /tmp/sys15-shellcheck.$$
    fail=$((fail + 1))
  fi
  rm -f /tmp/sys15-shellcheck.$$
else
  echo "  SKIP  shellcheck no instalado"
fi

out="$(bash "$script" "$csv" 2>/dev/null || true)"
if [[ -z "$out" ]]; then
  echo "  FAIL  el script no produjo salida"
  exit 1
fi

check_literal() {
  local needle="$1"
  if grep -Fq -- "$needle" <<<"$out"; then
    echo "  OK    salida contiene: $needle"
  else
    echo "  FAIL  salida NO contiene: $needle"
    fail=$((fail + 1))
  fi
}

# Totales agregados.
check_literal "sum=378"
check_literal "avg=54.00"
check_literal "min=8"
check_literal "max=99"

# Clasificaciones por host esperadas (lista "host:clase").
expected_pairs=(
  "web-01:idle"
  "web-02:normal"
  "db-01:busy"
  "db-02:critical"
  "cache-01:idle"
  "cache-02:normal"
  "batch-01:critical"
)

for pair in "${expected_pairs[@]}"; do
  host="${pair%%:*}"
  expected="${pair##*:}"
  if grep -Eq "^${host}[[:space:]].*[[:space:]]${expected}([[:space:]]|$)" <<<"$out"; then
    echo "  OK    $host => $expected"
  else
    echo "  FAIL  $host no clasificado como $expected"
    fail=$((fail + 1))
  fi
done

# Deben aparecer 7 filas clasificadas.
rows=$(grep -cE '^(web|db|cache|batch)-[0-9]+[[:space:]]' <<<"$out" || true)
if (( rows == 7 )); then
  echo "  OK    filas clasificadas: 7"
else
  echo "  FAIL  filas clasificadas: $rows (esperado 7)"
  fail=$((fail + 1))
fi

echo
if (( fail > 0 )); then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK: actividad completada correctamente."
