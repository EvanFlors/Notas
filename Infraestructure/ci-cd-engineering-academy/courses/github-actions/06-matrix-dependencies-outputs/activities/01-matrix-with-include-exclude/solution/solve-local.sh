#!/usr/bin/env bash
# Reference solution for gha-06-01-matrix-with-include-exclude in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/gha-06-01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$BASE/local/.github/workflows/ci.yml" <<'EOF'
name: ci
on:
  push:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    name: test (${{ matrix.os }} / py${{ matrix.python }}${{ matrix.experimental && ' [exp]' || '' }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, macos-latest]
        python: ['3.11', '3.12']
        exclude:
          # Hypothetical: python 3.11 unsupported by a dependency on macOS.
          - os: macos-latest
            python: '3.11'
        include:
          # Extra combo: 3.13 on Ubuntu, marked experimental so it won't tank CI.
          - os: ubuntu-latest
            python: '3.13'
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - name: Run tests
        continue-on-error: ${{ matrix.experimental == true }}
        run: |
          python --version
          echo "ok ${{ matrix.os }} / ${{ matrix.python }}"
EOF

cd "$BASE/local"
git add .github/workflows/ci.yml
git commit -q -m "ci: matrix 2D with exclude + experimental include"

echo
echo "== Done. State: =="
git log --oneline
