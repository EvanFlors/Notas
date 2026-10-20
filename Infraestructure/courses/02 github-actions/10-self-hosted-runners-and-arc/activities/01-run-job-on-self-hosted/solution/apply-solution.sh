#!/usr/bin/env bash
# Aplica la solución de la actividad 01 sobre un bootstrap ya hecho.
set -eu
DEST="${1:-/tmp/sh-runner}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$DEST/actions-runner" ] || [ ! -d "$DEST/workflows" ]; then
  echo "[fail] $DEST no fue inicializado por starter/bootstrap.sh" >&2
  exit 1
fi

cp "$HERE/runner-config.env" "$DEST/actions-runner/runner-config.env"
cp "$HERE/.runner"           "$DEST/actions-runner/.runner"
cp "$HERE/hello-self-hosted.yml" "$DEST/workflows/hello-self-hosted.yml"

echo "[ok] solución aplicada en $DEST"
