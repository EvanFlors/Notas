#!/usr/bin/env bash
# Reference solution for gha-04-01-use-three-marketplace-actions.
# Runs the bootstrap and then writes a fully pinned ci.yml.
set -euo pipefail

BASE="${1:-/tmp/gha-04-01-use-three-marketplace-actions}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$BASE/repo/.github/workflows/ci.yml" <<'EOF'
name: CI (3 marketplace actions, all pinned to SHA)

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0
        with:
          python-version: '3.12'

      - uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}

      - name: Say hi
        run: echo "all three actions above are pinned to SHA + # vSEMVER"
EOF

echo
echo "== Solution written =="
echo "File: $BASE/repo/.github/workflows/ci.yml"
