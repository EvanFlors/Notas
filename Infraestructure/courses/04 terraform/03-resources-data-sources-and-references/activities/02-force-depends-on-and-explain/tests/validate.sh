#!/usr/bin/env bash
# Validate tf-03-02-force-depends-on-and-explain.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `grep -q` on piped input; a premature match triggers SIGPIPE
# upstream and pipefail would promote that to a false failure.

WORK="${WORK_DIR:-/tmp/tf-03-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: terraform ---
if ! command -v terraform >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'terraform' no está instalado. Instala desde:
  https://developer.hashicorp.com/terraform/install
EOF
  exit 0
fi

# --- Preflight: docker ---
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker CLI o daemon no disponibles."
  exit 0
fi

ok "terraform y docker disponibles"

# --- Setup workspace si no existe ---
HERE="$(cd "$(dirname "$0")/.." && pwd)"
STARTER="$HERE/starter"
if [ ! -d "$WORK/scenario-A" ] || [ ! -d "$WORK/scenario-B" ]; then
  echo "== Preparando workspace en $WORK (desde starter) =="
  mkdir -p "$WORK"
  cp -R "$STARTER/." "$WORK/"
  echo "   Nota: el starter trae TODOs; rellénalos antes de volver a correr."
fi

SA="$WORK/scenario-A"
SB="$WORK/scenario-B"

# --- Chequeo A1: scenario-A no tiene depends_on ---
if grep -q 'depends_on' "$SA/main.tf"; then
  bad "scenario-A/main.tf aún contiene 'depends_on' (debe eliminarse)"
else
  ok "scenario-A sin depends_on"
fi

# --- Chequeo B1: scenario-B tiene depends_on a null_resource.marker ---
if grep -qE 'depends_on\s*=\s*\[\s*null_resource\.marker' "$SB/main.tf"; then
  ok "scenario-B tiene depends_on = [null_resource.marker]"
else
  bad "scenario-B no tiene depends_on apuntando a null_resource.marker"
fi

# --- Chequeo B2: hay un comentario (línea con '#') dentro del bloque container ---
# Buscamos el bloque "resource \"docker_container\" \"app\"" y comprobamos que
# haya al menos un comentario con '#' dentro de él.
if awk '
  /resource "docker_container" "app"/ { inblk=1 }
  inblk && /^[[:space:]]*#/ { found=1 }
  inblk && /^}/ { inblk=0 }
  END { exit (found ? 0 : 1) }
' "$SB/main.tf"; then
  ok "scenario-B: depends_on viene con comentario dentro del bloque"
else
  bad "scenario-B: falta comentario justificando el depends_on dentro del bloque docker_container.app"
fi

# --- Chequeo 3: ANSWER.md existe con secciones obligatorias ---
ANS="$WORK/ANSWER.md"
if [ ! -f "$ANS" ]; then
  bad "falta $ANS (crea el archivo con las tres secciones requeridas)"
else
  ok "ANSWER.md presente"
  for section in "Escenario A" "Escenario B" "Regla práctica"; do
    if grep -qF "$section" "$ANS"; then
      ok "ANSWER.md contiene sección '$section'"
    else
      bad "ANSWER.md no contiene sección '$section'"
    fi
  done
fi

# --- Chequeo 4: ambos escenarios aplican y destruyen ---
run_tf_cycle() {
  local dir="$1" tag="$2"
  (
    cd "$dir" || exit 2
    terraform init -no-color -input=false >/tmp/tf-03-02.$tag.init.log 2>&1 || exit 10
    terraform apply -auto-approve -no-color -input=false >/tmp/tf-03-02.$tag.apply.log 2>&1 || exit 11
    terraform destroy -auto-approve -no-color -input=false >/tmp/tf-03-02.$tag.destroy.log 2>&1 || exit 12
  )
}

if run_tf_cycle "$SA" A; then
  ok "scenario-A: init+apply+destroy OK"
else
  bad "scenario-A: init/apply/destroy falló (ver /tmp/tf-03-02.A.*.log)"
fi

if run_tf_cycle "$SB" B; then
  ok "scenario-B: init+apply+destroy OK"
else
  bad "scenario-B: init/apply/destroy falló (ver /tmp/tf-03-02.B.*.log)"
fi

# --- Teardown defensivo ---
docker rm -f tf-03-02-nginx tf-03-02-app >/dev/null 2>&1 || true

echo ""
echo "== Reporte =="
echo -e "$report"
echo "RESUMEN: $passed OK, $failed FAIL"
[ "$failed" -eq 0 ]
