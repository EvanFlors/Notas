#!/usr/bin/env bash
# Copy the reference solution Dockerfile into the learner workspace. Useful
# to smoke-test the validator or when a learner wants to see the target.
set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE no existe. Corre starter/bootstrap.sh primero." >&2
  exit 1
fi

cp "$HERE/Dockerfile" "$BASE/Dockerfile"
echo "Reference solution Dockerfile applied to $BASE/Dockerfile"
