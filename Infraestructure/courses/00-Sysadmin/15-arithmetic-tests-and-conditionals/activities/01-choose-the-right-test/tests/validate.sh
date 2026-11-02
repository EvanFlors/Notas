#!/usr/bin/env bash
# validate.sh — compara las respuestas del estudiante con la solución.
# Uso: bash tests/validate.sh [answers_file]
# Por defecto: starter/questions.md.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
student="${1:-$root/starter/questions.md}"
key="$root/solution/answers.md"

if [[ ! -f "$student" ]]; then
  echo "FAIL: no existe archivo del estudiante: $student" >&2
  exit 1
fi
if [[ ! -f "$key" ]]; then
  echo "FAIL: no existe solución: $key" >&2
  exit 1
fi

# Extrae pares (n, operator, wrapper) de un archivo markdown con bloques "## N".
extract() {
  local file="$1"
  awk '
    /^##[[:space:]]+[0-9]+/ { n=$2; op=""; wr=""; next }
    /^-[[:space:]]*operator:/ {
      sub(/^-[[:space:]]*operator:[[:space:]]*/, "")
      gsub(/[[:space:]]+/, " ")
      sub(/^ /, ""); sub(/ $/, "")
      op=$0
    }
    /^-[[:space:]]*wrapper:/ {
      sub(/^-[[:space:]]*wrapper:[[:space:]]*/, "")
      gsub(/[[:space:]]+/, " ")
      sub(/^ /, ""); sub(/ $/, "")
      wr=$0
      if (n != "" && op != "" && wr != "") {
        printf "%s|%s|%s\n", n, op, wr
      }
    }
  ' "$file"
}

tmp_student="$(mktemp)"
tmp_key="$(mktemp)"
trap 'rm -f "$tmp_student" "$tmp_key"' EXIT

extract "$student" | sort -t'|' -k1,1n > "$tmp_student"
extract "$key"     | sort -t'|' -k1,1n > "$tmp_key"

total=$(wc -l < "$tmp_key" | tr -d ' ')
ok=0
fail=0

while IFS='|' read -r n op_key wr_key; do
  line_s="$(awk -F'|' -v n="$n" '$1==n {print; exit}' "$tmp_student" || true)"
  if [[ -z "$line_s" ]]; then
    echo "  FAIL  escenario $n: respuesta ausente (esperado operator='$op_key' wrapper='$wr_key')"
    fail=$((fail + 1))
    continue
  fi
  op_s="$(printf '%s\n' "$line_s" | awk -F'|' '{print $2}')"
  wr_s="$(printf '%s\n' "$line_s" | awk -F'|' '{print $3}')"
  if [[ "$op_s" == "$op_key" && "$wr_s" == "$wr_key" ]]; then
    echo "  OK    escenario $n"
    ok=$((ok + 1))
  else
    echo "  FAIL  escenario $n: tienes operator='$op_s' wrapper='$wr_s' ; esperado operator='$op_key' wrapper='$wr_key'"
    fail=$((fail + 1))
  fi
done < "$tmp_key"

echo
echo "RESULT: $ok/$total correctos."
if (( fail > 0 )); then
  echo "FAIL: $fail incorrectos."
  exit 1
fi
echo "OK: actividad completada correctamente."
