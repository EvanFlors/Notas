#!/usr/bin/env bash
# Validate tf-10-02-reconcile-drift-safely.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Checks that pipe
# into `grep -q` can see SIGPIPE (exit 141) from the upstream command when
# grep matches early; pipefail would wrongly fail those checks.

WORK="${WORK_DIR:-/tmp/tf-10-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: 'terraform' no está instalado (>= 1.5 requerido)."
  exit 0
fi

if [ ! -d "$WORK" ]; then
  bad "no existe $WORK (debes ejecutar el starter)"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

cd "$WORK" || { echo "RESULT: FAIL — no pude entrar a $WORK"; exit 1; }

# --- decision.md ---
dec="$WORK/decision.md"
if [ ! -f "$dec" ]; then
  bad "no existe $dec"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi
ok "decision.md existe"

# normalizar: minúsculas, buscar la primera ocurrencia de accept|revert
# bajo "camino elegido"
choice=""
if grep -Eiq '^accept|^\s*accept\s*$' "$dec" || grep -Eiq 'camino elegido[^A-Za-z]*accept' "$dec"; then
  choice="accept"
fi
if grep -Eiq '^revert|^\s*revert\s*$' "$dec" || grep -Eiq 'camino elegido[^A-Za-z]*revert' "$dec"; then
  if [ -n "$choice" ]; then
    bad "decision.md menciona 'accept' Y 'revert'; declara solo uno"
    choice=""
  else
    choice="revert"
  fi
fi

if [ -z "$choice" ]; then
  bad "decision.md no declara 'accept' ni 'revert' como camino"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi
ok "camino declarado: $choice"

if ! grep -Eiq '(justificaci|motiv|razon|porque|por qu)' "$dec"; then
  bad "decision.md carece de justificación textual"
else
  ok "decision.md incluye justificación"
fi

# --- note.txt coherente con el camino ---
if [ ! -f "$WORK/note.txt" ]; then
  bad "no existe $WORK/note.txt"
else
  content="$(cat "$WORK/note.txt")"
  case "$choice" in
    accept)
      if printf '%s' "$content" | grep -qi 'hotfix'; then
        ok "note.txt refleja el drift aceptado (contiene 'hotfix')"
      else
        bad "accept declarado pero note.txt no contiene 'hotfix' (contenido: $content)"
      fi
      # con local_file, accept implica retirar el bloque del HCL o importar
      if grep -q 'resource "local_file" "note"' "$WORK/main.tf"; then
        bad "accept: local_file.note sigue declarado en main.tf; retira el bloque o re-importa (ver solución)"
      else
        ok "accept: local_file.note ya no está en main.tf (adopción fuera de TF)"
      fi
      ;;
    revert)
      if printf '%s' "$content" | grep -q 'contenido canonico'; then
        ok "note.txt refleja el revert (vuelve al content canónico)"
      else
        bad "revert declarado pero note.txt no es el canónico (contenido: $content)"
      fi
      if grep -q 'resource "local_file" "note"' "$WORK/main.tf"; then
        ok "revert: local_file.note sigue declarado en main.tf"
      else
        bad "revert: local_file.note debería seguir en main.tf"
      fi
      ;;
  esac
fi

# --- state consistente: plan debe ser no-op ---
if ! terraform init -input=false -no-color >/dev/null 2>&1; then
  bad "terraform init falló"
else
  terraform plan -no-color -detailed-exitcode >/dev/null 2>&1
  code=$?
  if [ "$code" -eq 0 ]; then
    ok "terraform plan reporta sin cambios (state consistente)"
  else
    bad "terraform plan propone cambios (exit=$code); drift sin resolver"
  fi
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
