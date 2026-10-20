#!/usr/bin/env bash
# Build a scratch workspace with a monolithic all-in-one workflow (bad).
set -euo pipefail

DEST="${1:-/tmp/share-build-artifact}"
rm -rf "$DEST"
mkdir -p "$DEST/.github/workflows"

cat > "$DEST/.github/workflows/pipeline.yml" <<'EOF'
name: Monolithic pipeline (needs splitting)

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  all-in-one:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: |
          mkdir -p dist
          echo "version=$(git rev-parse --short HEAD 2>/dev/null || echo local)" > dist/VERSION
          echo "built at $(date -u +%FT%TZ)" > dist/app.txt

      - name: Test
        run: |
          test -s dist/app.txt
          test -s dist/VERSION

      - name: Deploy
        run: echo "Deploying $(cat dist/VERSION)"
EOF

echo "OK: starter listo en $DEST"
echo "Edita $DEST/.github/workflows/pipeline.yml para dividir en build / test / deploy con artifacts."
