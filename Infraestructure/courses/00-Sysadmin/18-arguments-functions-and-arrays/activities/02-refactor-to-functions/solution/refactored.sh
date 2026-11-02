#!/usr/bin/env bash
#
# refactored.sh — solución de referencia de sys-18-02.
#
# Cambios respecto al monolito:
#   - Config por entorno movida a un array asociativo CONFIG con claves
#     "env.key" (dev.host, prod.port, ...). Añadir un entorno nuevo es
#     una entrada en el array, sin tocar lógica.
#   - Flujo partido en funciones: usage / die / parse_args / load_config /
#     validate_env / notice / build / publish / main.
#   - Toda variable interna de función es `local`. Solo CONFIG / PROG /
#     VERSION son globales por diseño.
#   - `main "$@"` como última línea; el resto son definiciones.
#
set -euo pipefail
IFS=$'\n\t'

readonly PROG="${0##*/}"
readonly VERSION="1.0.0"

declare -A CONFIG=()

# ----------- utilidades -----------
usage() {
    cat <<EOF
Uso: $PROG [-e ENV] -a ARTIFACT [-d] [-h]
  -e ENV        Entorno destino (dev, stage, prod, qa). Default: dev
  -a ARTIFACT   Nombre del artefacto (obligatorio)
  -d            Dry-run (no publica, solo imprime acciones)
  -h            Ayuda
Exit codes: 0 ok, 2 error de uso.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 2
}

# ----------- configuración -----------
load_config() {
    CONFIG[dev.host]="dev.example.com"
    CONFIG[dev.port]="8080"
    CONFIG[dev.user]="dev-deploy"

    CONFIG[stage.host]="stage.example.com"
    CONFIG[stage.port]="8443"
    CONFIG[stage.user]="stage-deploy"

    CONFIG[prod.host]="prod.example.com"
    CONFIG[prod.port]="443"
    CONFIG[prod.user]="prod-deploy"

    CONFIG[qa.host]="qa.example.com"
    CONFIG[qa.port]="8443"
    CONFIG[qa.user]="qa-deploy"
}

validate_env() {
    local env=$1
    [[ -n "${CONFIG[$env.host]:-}" ]] || die "entorno inválido: $env"
}

# ----------- parsing (setea globales env/artifact/dry) -----------
parse_args() {
    env="dev"
    artifact=""
    dry=0
    local OPTIND=1 opt
    while getopts ":he:a:d" opt; do
        case "$opt" in
            h) usage; exit 0 ;;
            e) env="$OPTARG" ;;
            a) artifact="$OPTARG" ;;
            d) dry=1 ;;
            \?) die "opción desconocida: -$OPTARG" ;;
            :)  die "la opción -$OPTARG requiere argumento" ;;
        esac
    done
    [[ -n "$artifact" ]] || die "-a ARTIFACT es obligatorio"
}

# ----------- pasos de pipeline -----------
notice() {
    local env=$1
    case "$env" in
        dev)   echo "[info] entorno dev no requiere confirmación" ;;
        stage) echo "[info] entorno stage: validando hora de despliegue" ;;
        prod)  echo "[warn] entorno prod: validaciones estrictas aplicadas" ;;
        *)     echo "[info] entorno $env: sin aviso especial" ;;
    esac
}

build() {
    local env=$1 artifact=$2
    local tarball="${artifact}-${env}.tar.gz"
    local host="${CONFIG[$env.host]}"
    local port="${CONFIG[$env.port]}"
    local user="${CONFIG[$env.user]}"
    echo "[build] empaquetando $artifact -> $tarball"
    echo "[build] destino: $user@$host:$port"
}

publish() {
    local env=$1 artifact=$2 dry=$3
    local tarball="${artifact}-${env}.tar.gz"
    local host="${CONFIG[$env.host]}"
    local port="${CONFIG[$env.port]}"
    local user="${CONFIG[$env.user]}"
    if (( dry )); then
        echo "DRY RUN: habría publicado $tarball a $user@$host:$port"
    else
        echo "PUBLICANDO $tarball a $user@$host:$port"
    fi
}

# ----------- orquestador -----------
main() {
    load_config
    parse_args "$@"
    validate_env "$env"
    notice "$env"
    build   "$env" "$artifact"
    publish "$env" "$artifact" "$dry"
    echo "[done] env=$env artifact=$artifact"
}

main "$@"
