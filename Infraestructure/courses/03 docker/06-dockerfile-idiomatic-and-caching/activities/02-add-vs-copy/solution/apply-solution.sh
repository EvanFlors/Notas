#!/usr/bin/env bash
set -eu
BASE="${BASE_DIR:-/tmp/dkr-06-02}"
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$BASE" ]; then
  echo "Workspace $BASE not found. Run starter/bootstrap.sh first." >&2
  exit 1
fi
cp "$HERE/Dockerfile" "$BASE/Dockerfile"
echo "Reference Dockerfile applied at $BASE/Dockerfile"
