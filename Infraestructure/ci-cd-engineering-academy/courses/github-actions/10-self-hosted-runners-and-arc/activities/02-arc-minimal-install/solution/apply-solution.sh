#!/usr/bin/env bash
# Aplica la solución: copia el ADR y, si la toolchain está, levanta la infra.
set -eu
DEST="${1:-/tmp/arc-mini}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$DEST/docs" ]; then
  echo "[fail] $DEST no fue inicializado por starter/bootstrap.sh" >&2
  exit 1
fi

cp "$HERE/ADR-001-runner-choice.md" "$DEST/docs/ADR-001-runner-choice.md"
echo "[ok] ADR copiado"

if command -v docker >/dev/null && command -v kind >/dev/null \
   && command -v kubectl >/dev/null && command -v helm >/dev/null; then
  echo "[info] toolchain disponible; aplicando infra..."
  bash "$DEST/bin/apply-infra.sh"
else
  echo "[info] falta alguna herramienta (docker/kind/kubectl/helm); validador correrá en docs-only"
fi
