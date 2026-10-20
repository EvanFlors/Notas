#!/usr/bin/env bash
# Smoke: valida que el shell puede listar el directorio de la actividad.
#
# NOTE: deliberately NO `set -o pipefail`. Grep en pipelines con
# pipefail reportaria SIGPIPE (141) espurio cuando grep sale pronto.
set -eu

ACT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ACT_DIR/README.md" ]
echo "smoke OK"
