#!/usr/bin/env bash
# Reference solution for gha-06-02-fan-out-fan-in in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/gha-06-02}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cat > "$BASE/local/.github/workflows/pipeline.yml" <<'EOF'
name: pipeline
on:
  push:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      sample_sha: ${{ steps.hash.outputs.sha }}
      sample_target: ${{ steps.hash.outputs.target }}
    strategy:
      fail-fast: false
      matrix:
        target: [alpha, beta, gamma]
    steps:
      - uses: actions/checkout@v4
      - id: hash
        name: Compute per-target sha
        run: |
          TARGET="${{ matrix.target }}"
          SHORT="$(echo -n "$TARGET-${GITHUB_SHA}" | shasum | cut -c1-7)"
          echo "sha=$SHORT"       >> "$GITHUB_OUTPUT"
          echo "target=$TARGET"   >> "$GITHUB_OUTPUT"
          echo "Built $TARGET -> $SHORT"

  aggregate:
    needs: build
    if: always() && !cancelled()
    runs-on: ubuntu-latest
    steps:
      - name: Summarize
        env:
          BUILD_RESULT: ${{ needs.build.result }}
          SAMPLE_TARGET: ${{ needs.build.outputs.sample_target }}
          SAMPLE_SHA: ${{ needs.build.outputs.sample_sha }}
        run: |
          {
            echo "## Pipeline summary"
            echo ""
            echo "- **build (matrix) result:** \`$BUILD_RESULT\`"
            echo "- **sample output (one matrix combination):** \`$SAMPLE_TARGET -> $SAMPLE_SHA\`"
            echo ""
            echo "### Targets"
            echo ""
            echo "| target | expected |"
            echo "| ------ | -------- |"
            for t in alpha beta gamma; do
              echo "| $t | built |"
            done
          } >> "$GITHUB_STEP_SUMMARY"
EOF

cd "$BASE/local"
git add .github/workflows/pipeline.yml
git commit -q -m "ci: fan-out/fan-in pipeline with aggregator summary"

echo
echo "== Done. State: =="
git log --oneline
