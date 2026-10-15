#!/usr/bin/env bash
# Validate tf-06-02-adopt-and-evaluate-a-registry-module.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `... | grep -q ...` patterns; if grep matches early it can trigger SIGPIPE
# (exit 141) on the upstream command, which pipefail would promote to a
# pipeline failure — a false negative.

WORK="${WORK_DIR:-/tmp/tf-06-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: git disponible ---
if ! command -v git >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'git' no está instalado. Instala git y vuelve a correr:
  - macOS:  xcode-select --install   (o: brew install git)
  - Linux:  https://git-scm.com/download/linux
EOF
  exit 0
fi

echo "== Validando evaluación en: $WORK =="

# --- 1. module-src existe y es un repo git ---
if [ -d "$WORK/module-src/.git" ]; then
  ok "module-src/ es un repositorio git clonado"
else
  bad "no existe $WORK/module-src/ como repo git (hiciste 'git clone'?)"
fi

# --- 2. EVALUATION.md existe ---
EV="$WORK/EVALUATION.md"
if [ ! -f "$EV" ]; then
  bad "falta $EV"
  printf "%b\n" "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL (falta EVALUATION.md)"
  exit 1
fi
ok "EVALUATION.md existe"

# --- 3. Secciones requeridas ---
required_sections=(
  "Módulo evaluado"
  "Mantenimiento"
  "Pin de providers"
  "Safe defaults"
  "Tests"
  "Documentación"
  "SemVer y breaking changes"
  "Superficie"
  "Riesgos"
  "Veredicto"
)

# Para cada sección: debe existir header '## <sección>' y tener contenido mínimo.
# Extraemos el bloque entre el header y el siguiente '## ' (o EOF).
for section in "${required_sections[@]}"; do
  # Escapar nada; grep -F para literal.
  if ! grep -qF "## $section" "$EV"; then
    bad "falta sección '## $section'"
    continue
  fi
  # Extraer contenido de la sección con awk.
  content="$(awk -v s="## $section" '
    index($0, s)==1 { capture=1; next }
    capture && /^## / { exit }
    capture { print }
  ' "$EV" | tr -d '\r' | sed '/^\s*$/d')"
  len="$(printf '%s' "$content" | wc -c | tr -d ' ')"
  # "Módulo evaluado" y "Veredicto" permitimos un poco menos; el resto 40+
  min=40
  if [ "$section" = "Módulo evaluado" ]; then min=20; fi
  if [ "$section" = "Veredicto" ]; then min=20; fi
  if [ "$len" -ge "$min" ]; then
    ok "sección '## $section' con contenido ($len chars)"
  else
    bad "sección '## $section' tiene $len chars (< $min); añade evidencia"
  fi
done

# --- 4. Veredicto contiene una de las tres palabras clave ---
verdict="$(awk '
  /^## Veredicto/ { capture=1; next }
  capture && /^## / { exit }
  capture { print }
' "$EV")"

if printf '%s' "$verdict" | grep -qiE 'adopt-con-cambios|adopt con cambios|\badopt\b|\breject\b'; then
  ok "Veredicto contiene adopt/adopt-con-cambios/reject"
else
  bad "Veredicto no contiene 'adopt', 'adopt-con-cambios' ni 'reject'"
fi

echo
printf "%b\n" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
