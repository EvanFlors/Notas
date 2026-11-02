#!/usr/bin/env bash
# Valida respuestas de la actividad 01-expansion-oracle.
# Compatible con Bash 3.2+ (sin arrays asociativos).
# Uso: bash tests/validate.sh [ruta/answers.md]

set -euo pipefail
IFS=$'\n\t'

if (( BASH_VERSINFO[0] < 4 )); then
  echo "WARN: Bash < 4 detectado (${BASH_VERSION}). Algunos snippets requieren Bash 4+" >&2
  echo "      (p.ej. \${var^^}). En macOS instala bash moderno: 'brew install bash'." >&2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
activity_dir="$(cd "$here/.." && pwd)"
questions="$activity_dir/starter/questions.md"

if [[ $# -ge 1 ]]; then
  answers="$1"
elif [[ -f "$activity_dir/answers.md" ]]; then
  answers="$activity_dir/answers.md"
elif [[ -f "$activity_dir/starter/answers.md" ]]; then
  answers="$activity_dir/starter/answers.md"
else
  answers="$activity_dir/solution/answers.md"
fi

if [[ ! -f "$questions" ]]; then
  echo "ERROR: no encuentro $questions" >&2
  exit 2
fi
if [[ ! -f "$answers" ]]; then
  echo "ERROR: no encuentro answers.md (probaste con: $answers)" >&2
  exit 2
fi

# extract_block N file
# Imprime el bloque bajo "=== N ===" hasta el siguiente marker o EOF.
extract_block() {
  local n=$1
  local file=$2
  awk -v target="=== $n ===" '
    $0 ~ /^=== [0-9]+ ===$/ {
      if ($0 == target) { capture=1; next }
      else if (capture) { exit }
    }
    capture { print }
  ' "$file"
}

# Lista de N presentes en questions.md
ns=()
while IFS= read -r num; do
  ns+=("$num")
done < <(grep -E '^=== [0-9]+ ===$' "$questions" | awk '{print $2}' | sort -n)

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

pass=0
fail=0
total=0

for n in "${ns[@]}"; do
  total=$((total+1))
  snippet="$(extract_block "$n" "$questions")"
  expected="$(extract_block "$n" "$answers")"

  # strip trailing newlines
  snippet="${snippet%$'\n'}"
  expected="${expected%$'\n'}"

  if [[ -z $expected ]]; then
    printf '[%2s] FAIL (sin respuesta)\n' "$n"
    fail=$((fail+1))
    continue
  fi

  actual="$(cd "$workdir" && bash -c "$snippet" 2>/dev/null || true)"
  actual="${actual%$'\n'}"

  if [[ "$actual" == "$expected" ]]; then
    printf '[%2s] OK\n' "$n"
    pass=$((pass+1))
  else
    printf '[%2s] FAIL\n' "$n"
    fail=$((fail+1))
  fi
done

echo
if [[ $fail -eq 0 ]]; then
  printf 'OK (%d/%d)\n' "$pass" "$total"
  exit 0
else
  printf 'FAIL (%d/%d correctas)\n' "$pass" "$total"
  exit 1
fi
