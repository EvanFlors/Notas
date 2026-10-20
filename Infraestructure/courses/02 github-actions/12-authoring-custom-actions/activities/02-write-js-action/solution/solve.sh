#!/usr/bin/env bash
# Reference solution: rebuild lab and drop in the model action.yml + index.js.
set -euo pipefail

BASE="${1:-/tmp/js-action-lab}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"
cp "$HERE/action.yml" "$BASE/line-counter/action.yml"
cp "$HERE/index.js"   "$BASE/line-counter/src/index.js"
cp "$HERE/index.js"   "$BASE/line-counter/dist/index.js"

echo "Solution installed in: $BASE/line-counter"
echo "Validate with: bash $HERE/../tests/validate.sh $BASE"
