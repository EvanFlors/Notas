#!/usr/bin/env bash
# Validate helm-06-02-split-umbrella-decision ADRs.
#
# Note: no `set -o pipefail`; several checks pipe into `grep -q`, which can
# produce SIGPIPE and pipefail would spuriously mark them as failures.

DIR="${1:-/tmp/helm06-act02}"
passed=0
failed=0
report=""

check() {
  local name="$1"; local ok="$2"; local why="${3:-}"
  if [ "$ok" -eq 1 ]; then
    report+="  OK  — $name\n"; passed=$((passed+1))
  else
    report+="  FAIL — $name${why:+ ($why)}\n"; failed=$((failed+1))
  fi
}

REQUIRED_SECTIONS=("## Status" "## Context" "## Decision" "## Consequences" "## Alternatives considered")
KEYWORDS=("ownership" "lifecycle" "blast radius")

if [ ! -d "$DIR" ]; then
  echo "FAIL: directorio $DIR no existe. Crea los 3 ADRs allí (ver README)."
  exit 1
fi

echo "== Validating ADRs under $DIR =="

for letter in A B C; do
  files=( "$DIR"/adr-"$letter"-*.md )
  if [ ! -f "${files[0]}" ]; then
    check "existe adr-$letter-*.md" 0 "no file"
    continue
  fi
  file="${files[0]}"
  check "existe adr-$letter-*.md" 1

  # sections present
  missing=""
  for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -qF "$section" "$file"; then
      missing+="$section "
    fi
  done
  if [ -z "$missing" ]; then
    check "ADR $letter tiene las 5 secciones" 1
  else
    check "ADR $letter tiene las 5 secciones" 0 "faltan: $missing"
  fi

  # decision mentions umbrella or separados
  dec_block=$(awk '/^## Decision/{flag=1;next} /^## /{flag=0} flag' "$file")
  if echo "$dec_block" | grep -qiE 'umbrella|separad'; then
    check "ADR $letter Decision menciona 'umbrella' o 'separados'" 1
  else
    check "ADR $letter Decision menciona 'umbrella' o 'separados'" 0 "ni 'umbrella' ni 'separados' en Decision"
  fi

  # at least two of the keywords across the ADR
  kw_count=0
  for kw in "${KEYWORDS[@]}"; do
    if grep -qiF "$kw" "$file"; then
      kw_count=$((kw_count+1))
    fi
  done
  if [ "$kw_count" -ge 2 ]; then
    check "ADR $letter menciona >=2 de: ownership/lifecycle/blast radius" 1
  else
    check "ADR $letter menciona >=2 de: ownership/lifecycle/blast radius" 0 "solo $kw_count de 3"
  fi

  # word count in [200, 600]
  wc_words=$(wc -w < "$file" | tr -d ' ')
  if [ "$wc_words" -ge 200 ] && [ "$wc_words" -le 600 ]; then
    check "ADR $letter longitud 200..600 palabras ($wc_words)" 1
  else
    check "ADR $letter longitud 200..600 palabras ($wc_words)" 0 "fuera de rango"
  fi
done

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
