#!/usr/bin/env bash
# Build the starter and apply the manual actions/cache@v4 variant (B).
set -euo pipefail

DEST="${1:-/tmp/cache-python-deps}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/../starter/build-starter.sh" "$DEST"

# Overwrite ci.yml with a solved version (variant B: actions/cache@v4 manual).
cat > "$DEST/.github/workflows/ci.yml" <<'EOF'
name: CI (with pip cache)

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Cache pip wheels
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-py3.12-pip-${{ hashFiles('**/requirements*.txt') }}
          restore-keys: |
            ${{ runner.os }}-py3.12-pip-

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: python -m pytest -q || true
EOF

echo "OK: solución aplicada en $DEST (variante B — actions/cache@v4)"
