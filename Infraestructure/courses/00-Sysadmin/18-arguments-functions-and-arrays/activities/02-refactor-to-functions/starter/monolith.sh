#!/usr/bin/env bash
#
# monolith.sh — publica un "release" a un entorno. Versión monolítica
# (sys-18-02 starter).  Tu tarea: refactorízalo. Ver README.md.
#
set -euo pipefail
IFS=$'\n\t'

PROG="${0##*/}"
VERSION="0.1.0"

env="dev"
artifact=""
dry=0

# ------------------------- parsing --------------------------
OPTIND=1
while getopts ":he:a:d" opt; do
    case "$opt" in
        h)
            cat <<EOF
Uso: $PROG [-e ENV] -a ARTIFACT [-d] [-h]
  -e ENV        Entorno destino (dev, stage, prod). Default: dev
  -a ARTIFACT   Nombre del artefacto (obligatorio)
  -d            Dry-run (no publica, solo imprime acciones)
  -h            Ayuda
Exit codes: 0 ok, 2 error de uso.
EOF
            exit 0
            ;;
        e) env="$OPTARG" ;;
        a) artifact="$OPTARG" ;;
        d) dry=1 ;;
        \?)
            echo "Error: opción desconocida: -$OPTARG" >&2
            exit 2
            ;;
        :)
            echo "Error: la opción -$OPTARG requiere argumento" >&2
            exit 2
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ -z "$artifact" ]]; then
    echo "Error: -a ARTIFACT es obligatorio" >&2
    exit 2
fi

# ------------------------- config por entorno (DUPLICADO) -------------------------
if [[ "$env" == "dev" ]]; then
    host="dev.example.com"
    port="8080"
    user="dev-deploy"
elif [[ "$env" == "stage" ]]; then
    host="stage.example.com"
    port="8443"
    user="stage-deploy"
elif [[ "$env" == "prod" ]]; then
    host="prod.example.com"
    port="443"
    user="prod-deploy"
else
    echo "Error: entorno inválido: $env" >&2
    exit 2
fi

# ------------------------- validaciones -------------------------
if [[ "$env" == "dev" ]]; then
    echo "[info] entorno dev no requiere confirmación"
elif [[ "$env" == "stage" ]]; then
    echo "[info] entorno stage: validando hora de despliegue"
elif [[ "$env" == "prod" ]]; then
    echo "[warn] entorno prod: validaciones estrictas aplicadas"
fi

# ------------------------- build -------------------------
tarball="${artifact}-${env}.tar.gz"
echo "[build] empaquetando $artifact -> $tarball"
echo "[build] destino: $user@$host:$port"

# ------------------------- publish -------------------------
if (( dry )); then
    echo "DRY RUN: habría publicado $tarball a $user@$host:$port"
else
    echo "PUBLICANDO $tarball a $user@$host:$port"
fi

echo "[done] env=$env artifact=$artifact"
