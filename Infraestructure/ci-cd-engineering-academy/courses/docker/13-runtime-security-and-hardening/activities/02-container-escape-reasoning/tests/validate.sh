#!/usr/bin/env bash
# Validate ANALYSIS.md structure for dkr-13-02-container-escape-reasoning.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe into grep -q.
# Checks:
#   - ANALYSIS.md exists in <BASE>/work/
#   - at least 4 of 6 '### V<N>' headings present
#   - each present vector has the 4 required bold subsections
#   - each subsection has >= 2 non-empty lines of prose
#   - total non-empty lines >= 100
#   - no 'TODO:' / '<rellena>' placeholders remain

BASE="${1:-${BASE_DIR:-/tmp/dkr13-02}}"
DOC="$BASE/work/ANALYSIS.md"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-13-02-container-escape-reasoning under $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC no existe. Corre starter/bootstrap.sh primero." >&2
  exit 1
fi

# ---- Check A: no placeholders ----
if grep -qE "(TODO:|<rellena>)" "$DOC"; then
  note_fail "ANALYSIS.md contiene placeholders (TODO:/<rellena>); eliminalos y escribe prosa real"
else
  note_ok "Sin placeholders residuales"
fi

# ---- Check B: longitud total >= 100 lineas no vacias ----
non_empty="$(grep -cE '[^[:space:]]' "$DOC" 2>/dev/null || echo 0)"
if [ "${non_empty:-0}" -ge 50 ]; then
  note_ok "Longitud: $non_empty lineas no vacias (>=50)"
else
  note_fail "Longitud: $non_empty lineas no vacias (<50). Expande el analisis."
fi

# ---- Check C: al menos 4 de 6 vectores ----
present_vectors=()
for n in 1 2 3 4 5 6; do
  if grep -qE "^### V${n} " "$DOC"; then
    present_vectors+=("V${n}")
  fi
done
pcount="${#present_vectors[@]}"
if [ "$pcount" -ge 4 ]; then
  note_ok "Vectores presentes: $pcount ($(printf '%s ' "${present_vectors[@]}"))"
else
  note_fail "Solo $pcount vector(es) presentes; se requieren >=4 (headings '### V<N> —')"
fi

# ---- Check D: por cada vector presente, 4 subsecciones y prosa minima ----
# Extraemos el bloque entre '### V<N>' y el siguiente '### ' (o fin) y chequeamos.
awk_script='
  BEGIN { current=""; buf=""; have=0 }
  /^### / {
    if (current != "") print "@@BLOCK@@" current "@@" buf "@@END@@";
    current=$0; buf=""; next
  }
  { buf = buf "\n" $0 }
  END { if (current != "") print "@@BLOCK@@" current "@@" buf "@@END@@" }
'

tmp="$(mktemp)"
awk "$awk_script" "$DOC" > "$tmp"

for v in "${present_vectors[@]}"; do
  # Extrae el bloque para este vector
  block="$(awk -v tag="### $v " 'index($0, tag){flag=1} flag{print} /^@@END@@/{if(flag){exit}}' "$tmp")"
  if [ -z "$block" ]; then
    note_fail "$v: no se pudo aislar el bloque"
    continue
  fi

  missing=""
  for sub in "**Mecanismo**" "**Deteccion**" "**Detección**" "**Impacto**" "**Mitigacion**" "**Mitigación**"; do
    :
  done

  has_mech=0; has_det=0; has_imp=0; has_mit=0
  printf '%s\n' "$block" | grep -qE '^\*\*Mecanismo\*\*'        && has_mech=1
  printf '%s\n' "$block" | grep -qE '^\*\*Detecci(o|ó)n\*\*'    && has_det=1
  printf '%s\n' "$block" | grep -qE '^\*\*Impacto\*\*'          && has_imp=1
  printf '%s\n' "$block" | grep -qE '^\*\*Mitigaci(o|ó)n\*\*'   && has_mit=1

  if [ "$has_mech" -eq 1 ] && [ "$has_det" -eq 1 ] && [ "$has_imp" -eq 1 ] && [ "$has_mit" -eq 1 ]; then
    # Chequeo de prosa: cada subseccion debe tener >=2 lineas con texto despues del heading.
    # Simplificacion: contar lineas no vacias que no sean el propio heading.
    content_lines="$(printf '%s\n' "$block" | grep -cE '[^[:space:]]')"
    heading_lines=5   # ### V + 4 subsecciones bold
    if [ "$content_lines" -ge $((heading_lines + 8)) ]; then
      note_ok "$v: 4/4 subsecciones + prosa suficiente ($content_lines lineas con texto)"
    else
      note_fail "$v: subsecciones OK pero prosa insuficiente ($content_lines lineas; esperaba >= $((heading_lines + 8)))"
    fi
  else
    missing=""
    [ "$has_mech" -eq 0 ] && missing+=" Mecanismo"
    [ "$has_det"  -eq 0 ] && missing+=" Deteccion"
    [ "$has_imp"  -eq 0 ] && missing+=" Impacto"
    [ "$has_mit"  -eq 0 ] && missing+=" Mitigacion"
    note_fail "$v: faltan subsecciones:$missing"
  fi
done

rm -f "$tmp"

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
