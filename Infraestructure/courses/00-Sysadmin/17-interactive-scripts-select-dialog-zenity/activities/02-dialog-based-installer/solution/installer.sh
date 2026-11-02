#!/usr/bin/env bash
# installer.sh — Solución de referencia.
# Instalador dual-mode con dialog/whiptail y fallback a select.

set -euo pipefail

APP_NAME="demo-app"
DEFAULT_TARGET="/opt/demo-app"
VALID_COMPONENTS=(core cli docs examples)

usage() {
  cat <<EOF
Uso: $0 [--target DIR] [--components a,b,c] [--yes] [--non-interactive]
        [--force-fallback] [-h|--help]

Flags:
  --target DIR           Directorio destino (default: $DEFAULT_TARGET).
  --components a,b,c     Lista separada por comas: ${VALID_COMPONENTS[*]}.
  --yes                  Asume confirmación afirmativa.
  --non-interactive      Fuerza modo flags-only (falla si falta un dato).
  --force-fallback       Ignora dialog/whiptail aunque estén instalados.
  -h, --help             Muestra esta ayuda.
EOF
}

# -------- parseo de flags --------
target=""
components_csv=""
assume_yes=0
non_interactive=0
force_fallback=0

while (($#)); do
  case "$1" in
    --target)          target="${2:?--target requiere valor}"; shift 2 ;;
    --components)      components_csv="${2:?--components requiere valor}"; shift 2 ;;
    --yes|-y)          assume_yes=1; shift ;;
    --non-interactive) non_interactive=1; shift ;;
    --force-fallback)  force_fallback=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "Flag desconocido: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# -------- helpers --------
is_interactive() {
  [[ -t 0 && -t 1 ]] && [[ "${CI:-}" != "true" ]] && (( non_interactive == 0 ))
}

pick_backend() {
  if (( force_fallback )); then echo "fallback"; return; fi
  if command -v dialog   >/dev/null 2>&1; then echo "dialog";   return; fi
  if command -v whiptail >/dev/null 2>&1; then echo "whiptail"; return; fi
  echo "fallback"
}

validate_components() {
  local csv="$1" c
  IFS=',' read -r -a arr <<< "$csv"
  for c in "${arr[@]}"; do
    local ok=0
    for v in "${VALID_COMPONENTS[@]}"; do [[ "$c" == "$v" ]] && ok=1; done
    (( ok )) || { echo "Componente inválido: '$c'. Válidos: ${VALID_COMPONENTS[*]}" >&2; return 1; }
  done
}

# -------- prompts por backend --------
ask_target_tui() {
  local tool="$1"
  "$tool" --title "$APP_NAME" --inputbox "Directorio destino:" 8 50 "$DEFAULT_TARGET" \
    3>&1 1>&2 2>&3
}

ask_components_tui() {
  local tool="$1"
  "$tool" --title "$APP_NAME" --separate-output \
    --checklist "Componentes a instalar (Space marca):" 15 50 4 \
    core     "Núcleo (obligatorio)" ON \
    cli      "Herramienta de línea de comandos" OFF \
    docs     "Documentación" OFF \
    examples "Ejemplos" OFF \
    3>&1 1>&2 2>&3 | paste -sd, -
}

confirm_tui() {
  local tool="$1" msg="$2"
  "$tool" --title "$APP_NAME" --yesno "$msg" 8 60
}

ask_target_fallback() {
  local ans=""
  read -r -p "Directorio destino [$DEFAULT_TARGET]: " ans
  echo "${ans:-$DEFAULT_TARGET}"
}

ask_components_fallback() {
  local chosen=()
  echo "Elige componentes (uno a uno; 'Terminar' para acabar):" >&2
  PS3="componente> "
  local opts=("${VALID_COMPONENTS[@]}" "Terminar")
  select o in "${opts[@]}"; do
    case "${REPLY:-}" in
      "") : ;;
      *)
        if [[ "$o" == "Terminar" ]]; then break; fi
        if [[ -n "$o" ]]; then
          chosen+=("$o")
          echo "  añadido: $o" >&2
        else
          echo "  opción inválida: '$REPLY'" >&2
        fi
        ;;
    esac
  done
  # Si no eligió nada, al menos core.
  (( ${#chosen[@]} == 0 )) && chosen=(core)
  (IFS=,; echo "${chosen[*]}")
}

confirm_fallback() {
  local msg="$1" ans=""
  read -r -n 1 -p "$msg (y/N)? " ans
  echo
  [[ "$ans" =~ ^[yY]$ ]]
}

# -------- "instalación" simulada --------
do_install() {
  local tgt="$1" comps="$2" backend="$3"
  if [[ "$backend" == "dialog" || "$backend" == "whiptail" ]]; then
    (
      echo 10; sleep 0.1
      echo 40; sleep 0.1
      echo 70; sleep 0.1
      echo 100
    ) | "$backend" --gauge "Instalando $APP_NAME en $tgt..." 7 60 0 || true
  else
    echo "Instalando $APP_NAME en $tgt (componentes: $comps)"
    for pct in 10 40 70 100; do
      printf '  [%3d%%] ...\n' "$pct"
    done
  fi
  echo "INSTALLED target=$tgt components=$comps"
}

# -------- main --------
backend="$(pick_backend)"

# Rellenar target
if [[ -z "$target" ]]; then
  if is_interactive; then
    case "$backend" in
      dialog|whiptail) target="$(ask_target_tui "$backend")" || { echo "Cancelado."; exit 1; } ;;
      fallback)        target="$(ask_target_fallback)" ;;
    esac
  else
    echo "Falta --target y no hay TTY o modo no-interactivo activo." >&2
    exit 2
  fi
fi
target="${target:-$DEFAULT_TARGET}"

# Rellenar components
if [[ -z "$components_csv" ]]; then
  if is_interactive; then
    case "$backend" in
      dialog|whiptail) components_csv="$(ask_components_tui "$backend")" || { echo "Cancelado."; exit 1; } ;;
      fallback)        components_csv="$(ask_components_fallback)" ;;
    esac
    [[ -z "$components_csv" ]] && components_csv="core"
  else
    echo "Falta --components y no hay TTY o modo no-interactivo activo." >&2
    exit 2
  fi
fi
validate_components "$components_csv"

# Confirmar
if (( assume_yes == 0 )); then
  if is_interactive; then
    case "$backend" in
      dialog|whiptail) confirm_tui "$backend" "Instalar $APP_NAME en:\n  $target\nComponentes: $components_csv\n\n¿Continuar?" \
                        || { echo "Cancelado por el usuario."; exit 1; } ;;
      fallback)        confirm_fallback "Instalar en $target ($components_csv)" \
                        || { echo "Cancelado por el usuario."; exit 1; } ;;
    esac
  else
    echo "No hay TTY y no se pasó --yes; abortando." >&2
    exit 2
  fi
fi

do_install "$target" "$components_csv" "$backend"
