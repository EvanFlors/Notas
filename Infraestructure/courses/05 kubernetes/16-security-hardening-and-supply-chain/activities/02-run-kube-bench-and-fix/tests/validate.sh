#!/usr/bin/env bash
# Validate REMEDIATIONS.md structure for k8s-16-02-run-kube-bench-and-fix.
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks hacen pipe a grep -q
# y pipefail reporta SIGPIPE (141) espurio.

BASE="${1:-${BASE_DIR:-/tmp/k8s-16-02}}"
DOC="$BASE/work/REMEDIATIONS.md"
OUT="$BASE/work/kube-bench.out"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating k8s-16-02-run-kube-bench-and-fix bajo $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC no existe. Corre starter/bootstrap.sh primero." >&2
  exit 1
fi

# ---- Check A: salida de kube-bench presente ----
if [ -f "$OUT" ] && [ "$(wc -c < "$OUT" 2>/dev/null || echo 0)" -gt 500 ]; then
  note_ok "kube-bench.out presente ($(wc -l < "$OUT") lineas)"
else
  note_fail "kube-bench.out ausente o muy corto ($OUT). Corre el Job y guarda la salida."
fi

# ---- Check B: sin placeholders residuales ----
if grep -qE "(TODO:|<rellena>)" "$DOC"; then
  note_fail "REMEDIATIONS.md contiene placeholders (TODO:/<rellena>); escribe prosa real"
else
  note_ok "Sin placeholders residuales"
fi

# ---- Check C: longitud minima ----
non_empty="$(grep -cE '[^[:space:]]' "$DOC" 2>/dev/null || echo 0)"
if [ "${non_empty:-0}" -ge 60 ]; then
  note_ok "Longitud: $non_empty lineas no vacias (>=60)"
else
  note_fail "Longitud: $non_empty lineas no vacias (<60). Expande el analisis."
fi

# ---- Check D: tres hallazgos H1 H2 H3 ----
present_h=()
for n in 1 2 3; do
  if grep -qE "^### H${n} " "$DOC"; then
    present_h+=("H${n}")
  fi
done
if [ "${#present_h[@]}" -eq 3 ]; then
  note_ok "Tres hallazgos presentes: H1 H2 H3"
else
  note_fail "Hallazgos presentes: ${#present_h[@]} (${present_h[*]:-ninguno}); se requieren 3"
fi

# ---- Check E: cada hallazgo tiene las 4 subsecciones ----
required_subs=("**Hallazgo**" "**Mecanismo**" "**Impacto**" "**Remediacion**")
for h in "${present_h[@]}"; do
  # Extrae el bloque de este hallazgo hasta el siguiente '### ' o fin
  block="$(awk -v tag="### $h " '
    index($0,tag){flag=1}
    flag{
      if (NR>1 && /^### / && !index($0,tag)) exit
      print
    }
  ' "$DOC")"
  missing=""
  for sub in "${required_subs[@]}"; do
    if ! printf '%s' "$block" | grep -qF "$sub"; then
      missing+="$sub "
    fi
  done
  if [ -z "$missing" ]; then
    note_ok "$h tiene las 4 subsecciones requeridas"
  else
    note_fail "$h falta subseccion(es): $missing"
  fi

  # Para cada subseccion presente, verifica >=2 lineas de prosa.
  for sub in "${required_subs[@]}"; do
    # 'prose' = lineas despues del heading hasta la siguiente subseccion/encabezado,
    #   excluyendo vacias y la propia subseccion.
    prose_lines="$(printf '%s' "$block" | awk -v s="$sub" '
      index($0,s){flag=1; next}
      flag{
        if (/^\*\*/ || /^### / || /^---/) exit
        if ($0 ~ /[^[:space:]]/) print
      }
    ' | wc -l | tr -d " ")"
    if [ "${prose_lines:-0}" -ge 2 ]; then
      :
    else
      note_fail "$h $sub tiene $prose_lines linea(s) de prosa (>=2)"
    fi
  done
done

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total controles OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
