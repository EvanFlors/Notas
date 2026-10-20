#!/usr/bin/env bash
# Reference solution for gha-12-01-write-composite-action.
# Rebuilds the lab and overwrites the student's action.yml with the model answer.
set -euo pipefail

BASE="${1:-/tmp/composite-action-lab}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"
cp "$HERE/action.yml" "$BASE/semver-check/action.yml"

echo "Solution copied to: $BASE/semver-check/action.yml"
echo "Validate with: bash $HERE/../tests/validate.sh $BASE"
