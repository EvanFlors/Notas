#!/usr/bin/env bash
# Build a scratch workspace with a workflow that does NOT cache pip.
set -euo pipefail

DEST="${1:-/tmp/cache-python-deps}"
rm -rf "$DEST"
mkdir -p "$DEST/.github/workflows"

cat > "$DEST/requirements.txt" <<'EOF'
pytest==8.3.3
requests==2.32.3
EOF

cat > "$DEST/.github/workflows/ci.yml" <<'EOF'
name: CI (no cache yet)

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

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: python -m pytest -q || true
EOF

echo "OK: starter listo en $DEST"
echo "Edita $DEST/.github/workflows/ci.yml para añadir caché."
