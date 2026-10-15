#!/usr/bin/env bash
# Bootstrap for gha-04-01-use-three-marketplace-actions.
# Creates a scratch dir with a starter workflow file full of TODOs.
set -euo pipefail

BASE="${1:-/tmp/gha-04-01-use-three-marketplace-actions}"
rm -rf "$BASE"
mkdir -p "$BASE/repo/.github/workflows"

cat > "$BASE/repo/.github/workflows/ci.yml" <<'EOF'
name: CI (starter — replace me)

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # TODO 1: elige una action para hacer checkout del repo y pinnea a SHA + # vX.Y.Z
      # - uses: actions/checkout@<SHA40>  # v4.2.2

      # TODO 2: elige una action para preparar un runtime (python, node, go, ...) y pinnea a SHA + # vX.Y.Z
      # - uses: actions/setup-python@<SHA40>  # v5.3.0

      # TODO 3: elige una tercera action distinta (cache, upload-artifact, ...) y pinnea a SHA + # vX.Y.Z
      # - uses: actions/cache@<SHA40>  # v4.1.2

      - name: Placeholder step
        run: echo "replace the TODOs above with 3 pinned uses:"
EOF

echo "== bootstrap OK =="
echo "Edit: $BASE/repo/.github/workflows/ci.yml"
echo "Validate: bash tests/validate.sh $BASE"
