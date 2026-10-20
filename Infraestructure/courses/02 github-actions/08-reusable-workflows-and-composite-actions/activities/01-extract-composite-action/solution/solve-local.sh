#!/usr/bin/env bash
# Reference solution for gha-08-01-extract-composite-action.
# Materializes the expected composite action + refactored workflow.
set -euo pipefail

BASE="${1:-/tmp/extract-composite}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"

mkdir -p "$BASE/.github/actions/setup-env"

cat > "$BASE/.github/actions/setup-env/action.yml" <<'EOF'
name: 'Setup env (python + poetry)'
description: 'Set up Python and install project deps with Poetry'

inputs:
  python-version:
    description: 'Python version'
    required: false
    default: '3.12'
  poetry-version:
    description: 'Poetry version pinned'
    required: false
    default: '1.8.3'

outputs:
  python-path:
    description: 'Path to the python binary used'
    value: ${{ steps.detect.outputs.python }}

runs:
  using: 'composite'
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}
        cache: 'pip'

    - name: Install Poetry
      shell: bash
      run: pip install "poetry==${{ inputs.poetry-version }}"

    - name: Install deps
      shell: bash
      run: poetry install --no-interaction --no-root

    - id: detect
      shell: bash
      run: echo "python=$(command -v python)" >> "$GITHUB_OUTPUT"
EOF

cat > "$BASE/.github/workflows/ci.yml" <<'EOF'
name: CI
on: [push, pull_request]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-env
      - run: poetry run ruff check .

  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-env
      - run: poetry run pytest -q

  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-env
      - run: poetry run pytest tests/integration -q
EOF

echo
echo "Done. State:"
find "$BASE" -not -path '*/.git*' | sort | sed "s|$BASE|.|"
