#!/usr/bin/env bash
# Bootstrap for gha-02-02-fix-script-injection.
# Creates /tmp/gha-02-02/local/.github/workflows/greet.yml with a workflow
# that contains multiple script-injection sinks. The student fixes it.
set -euo pipefail

BASE="${1:-/tmp/gha-02-02}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"

cat > "$BASE/local/.github/workflows/greet.yml" <<'EOF'
# VULNERABLE workflow — this is the exercise starter.
# It interpolates attacker-controlled github.event fields into `run:` blocks.
# Your job: fix every unsafe interpolation using the env var + "$VAR" pattern,
# WITHOUT changing the structure or the names/ids of the steps.
name: greet-contributor

on:
  pull_request:
    types: [opened, edited, synchronize]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Say hello using title
        id: hello
        run: |
          echo "Thanks for the PR titled: ${{ github.event.pull_request.title }}"

      - name: Show branch
        id: show_branch
        run: |
          echo "Head ref is ${{ github.event.pull_request.head.ref }}"

      - name: Echo body snippet
        id: body
        run: |
          echo "PR body starts with: ${{ github.event.pull_request.body }}"

      - name: Safe metadata
        id: meta
        run: |
          echo "sha=${{ github.sha }} repo=${{ github.repository }}"
EOF

echo "== gha-02-02 starter ready =="
echo "Vulnerable workflow written to: $BASE/local/.github/workflows/greet.yml"
echo
echo "Open it, find the unsafe interpolations, and fix them."
echo "Also create $BASE/local/EXPLANATION.md with the written answer."
echo
echo "Then validate with:"
echo "  MODE=local bash tests/validate.sh $BASE"
