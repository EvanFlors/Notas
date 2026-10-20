#!/usr/bin/env bash
# Validate otel-09-02: estructura del ADR.md.
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks usan
# `grep -q ...` tras `cat` y pipefail generaria SIGPIPE espurio.

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
ADR="${ADR:-$ACT/ADR.md}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating otel-09-02 (adr=$ADR) =="

if [ ! -f "$ADR" ]; then
  echo "FAIL: no se encontró $ADR"
  echo "       (copia starter/ADR.template.md a ADR.md en la carpeta de la actividad)"
  exit 1
fi

content="$(cat "$ADR")"

# Longitud razonable: 150..1500 palabras.
words=$(printf '%s' "$content" | wc -w | awk '{print $1}')
if [ "$words" -ge 150 ] && [ "$words" -le 1500 ]; then
  note_ok "Longitud razonable ($words palabras)"
else
  note_fail "Longitud fuera de rango ($words palabras; esperado 150..1500)"
fi

# Secciones obligatorias (encabezados de nivel 2).
for section in "Status" "Contexto" "Decisión" "Alternativas consideradas" \
               "Consecuencias" "Trade-offs por escala" "Distro por entorno" "Revisión"; do
  if printf '%s' "$content" | grep -qE "^## *${section}"; then
    note_ok "Sección presente: $section"
  else
    note_fail "Sección ausente: $section"
  fi
done

# Sub-apartados de escala.
for scale in "10 RPS" "1000 RPS" "100000 RPS"; do
  if printf '%s' "$content" | grep -qE "^### *.*${scale}"; then
    note_ok "Sub-apartado presente: $scale"
  else
    note_fail "Sub-apartado ausente: $scale (encabezado ### debe mencionarlo)"
  fi
done

# Keywords técnicas (al menos una ocurrencia).
for kw in "agent" "gateway" "sending_queue" "HPA" "distro"; do
  if printf '%s' "$content" | grep -qi "$kw"; then
    note_ok "Keyword presente: $kw"
  else
    note_fail "Keyword ausente: $kw"
  fi
done

# Tabla de distro por entorno: al menos 2 filas de datos.
# Heurística: líneas con dos pipes que no sean header/separator.
rows=$(printf '%s' "$content" | awk '
  /^## *Distro por entorno/ { f=1; next }
  f && /^## / { f=0 }
  f && /^\|/ && !/^\| *[-:]/ && !/Entorno/ { c++ }
  END { print c+0 }
')
if [ "${rows:-0}" -ge 2 ]; then
  note_ok "Tabla 'Distro por entorno' con $rows filas de datos"
else
  note_fail "Tabla 'Distro por entorno' necesita >= 2 filas de datos (hay $rows)"
fi

# Prohibido: template sin rellenar (presencia de "…" aislado como contenido).
dots=$(printf '%s' "$content" | grep -c '^|.*….*|' || true)
if [ "${dots:-0}" -gt 0 ]; then
  note_fail "La tabla parece tener filas sin rellenar ('…')"
else
  note_ok "No se detectaron filas de template sin rellenar en tablas"
fi

echo
echo "---- report ----"
printf "%b" "$report"
echo "passed=$passed  failed=$failed"
if [ "$failed" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
fi
exit 1
