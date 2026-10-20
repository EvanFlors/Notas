#!/usr/bin/env bash
# Reference solution for gha-05-02-restrict-github-token in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/gha-05-restrict-github-token}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

WF="$BASE/local/.github/workflows"

cat > "$WF/vulnerable.yml" <<'EOF'
# Hardened: contents: read at top-level, per-job minimal escalation with justification.
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    # No permissions block => inherits top-level contents: read.
    steps:
      - uses: actions/checkout@v4
      - name: run-lint
        run: echo "running lint..."

  comment-pr:
    if: github.event_name == 'pull_request'
    needs: lint
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # JUSTIFICATION: post lint summary comment on the PR
    steps:
      - uses: actions/checkout@v4
      - name: post-lint-summary
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          echo "would call: gh pr comment ... --body 'Lint OK'"

  publish-draft-release:
    if: github.ref == 'refs/heads/main'
    needs: lint
    runs-on: ubuntu-latest
    permissions:
      # JUSTIFICATION: create a draft release on main pushes
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: draft-release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          echo "would call: gh release create ... --draft"
EOF

echo "== solution written =="
cat "$WF/vulnerable.yml"
