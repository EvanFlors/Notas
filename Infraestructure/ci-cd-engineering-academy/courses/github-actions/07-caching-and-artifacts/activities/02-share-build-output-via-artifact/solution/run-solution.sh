#!/usr/bin/env bash
# Build starter and overwrite with the split build/test/deploy pipeline.
set -euo pipefail

DEST="${1:-/tmp/share-build-artifact}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/../starter/build-starter.sh" "$DEST"

cat > "$DEST/.github/workflows/pipeline.yml" <<'EOF'
name: Build / Test / Deploy with artifact

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build dist/
        run: |
          mkdir -p dist
          echo "version=$(git rev-parse --short HEAD 2>/dev/null || echo local)" > dist/VERSION
          echo "built at $(date -u +%FT%TZ)" > dist/app.txt

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-dist
          path: dist/
          retention-days: 7
          if-no-files-found: error

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - name: Verify bundle
        run: |
          test -s dist/app.txt
          test -s dist/VERSION

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - name: Deploy
        run: echo "Deploying $(cat dist/VERSION)"
EOF

echo "OK: solución aplicada en $DEST"
