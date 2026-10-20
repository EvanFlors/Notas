#!/usr/bin/env bash
# Reference solution: copia verify.sh y consume.yml al BASE.
set -euo pipefail

BASE="${1:-/tmp/gha-14-02}"
HERE="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"

if [ ! -f "$BASE/image-info.env" ]; then
  echo "FAIL: $BASE/image-info.env no existe. Corre starter/bootstrap.sh primero."
  exit 1
fi

cp "$HERE/verify.sh"   "$BASE/verify.sh"
chmod +x "$BASE/verify.sh"
cp "$HERE/consume.yml" "$BASE/.github/workflows/consume.yml"

echo "Solution copiada a $BASE."
echo "  verify.sh"
echo "  .github/workflows/consume.yml"
