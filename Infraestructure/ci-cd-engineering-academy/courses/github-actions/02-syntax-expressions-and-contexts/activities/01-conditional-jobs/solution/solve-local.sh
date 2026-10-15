#!/usr/bin/env bash
# Reference solution for gha-02-01-conditional-jobs in MODE=local.
# Writes the completed workflow and runs the validator.
set -euo pipefail

BASE="${1:-/tmp/gha-02-01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$BASE/local/.github/workflows/conditional.yml" <<'EOF'
name: conditional

on:
  push:
    branches: ['**']
  pull_request:
    branches: [main]

env:
  LOG_LEVEL: info

jobs:
  lint:
    runs-on: ubuntu-latest
    env:
      LOG_LEVEL: debug
    steps:
      - uses: actions/checkout@v4
      - name: Lint step
        id: check
        env:
          LOG_LEVEL: trace
        run: |
          echo "linting at $LOG_LEVEL"
          exit 0

  test:
    needs: lint
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Flaky step
        id: flaky
        continue-on-error: true
        run: |
          echo "simulating a flaky failure"
          exit 1
      - name: React to flaky outcome
        if: ${{ steps.flaky.outcome == 'failure' }}
        run: echo "flaky step failed but we continue"
      - name: On any failure
        if: ${{ failure() }}
        run: echo "at least one earlier step failed"
      - name: Always cleanup
        if: ${{ always() }}
        run: echo "cleanup runs regardless"

  deploy:
    needs: test
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && needs.test.result == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: echo "deploying ${{ github.sha }}"
EOF

echo
echo "== Solution written. Running validator: =="
MODE=local bash "$HERE/../tests/validate.sh" "$BASE"
