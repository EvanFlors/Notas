#!/usr/bin/env bash
# Bootstrap for gha-08-01-extract-composite-action.
# Creates a repo with a workflow that repeats the same 4 setup steps
# across 3 jobs. The student extracts those steps into a composite action.
set -euo pipefail

BASE="${1:-/tmp/extract-composite}"

echo "== Bootstrapping at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows"
mkdir -p "$BASE/tests/integration"

cat > "$BASE/pyproject.toml" <<'EOF'
[tool.poetry]
name = "sample-app"
version = "0.1.0"
description = "Sample app with duplicated CI setup"
authors = ["Student <student@example.com>"]
package-mode = false

[tool.poetry.dependencies]
python = ">=3.11,<3.14"

[tool.poetry.group.dev.dependencies]
ruff = "^0.6"
pytest = "^8"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
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
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      - run: pip install poetry==1.8.3
      - run: poetry install --no-interaction --no-root
      - run: poetry run ruff check .

  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      - run: pip install poetry==1.8.3
      - run: poetry install --no-interaction --no-root
      - run: poetry run pytest -q

  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      - run: pip install poetry==1.8.3
      - run: poetry install --no-interaction --no-root
      - run: poetry run pytest tests/integration -q
EOF

cat > "$BASE/README.md" <<'EOF'
# sample-app

CI with duplicated setup across three jobs. Refactor into a composite action.
EOF

echo
echo "Done. Starting point:"
find "$BASE" -not -path '*/.git*' | sort | sed "s|$BASE|.|"
echo
echo "Your tasks:"
echo "  1) Create $BASE/.github/actions/setup-env/action.yml (composite)."
echo "  2) Refactor $BASE/.github/workflows/ci.yml to call the composite."
echo "  3) Run: bash tests/validate.sh $BASE"
