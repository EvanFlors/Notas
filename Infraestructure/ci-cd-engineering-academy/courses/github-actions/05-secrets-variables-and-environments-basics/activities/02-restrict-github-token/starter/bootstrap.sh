#!/usr/bin/env bash
# Bootstrap for gha-05-02-restrict-github-token.
#
# Creates a working directory with a deliberately over-permissive workflow
# that the student must harden.
set -euo pipefail

BASE="${1:-/tmp/gha-05-restrict-github-token}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"

cat > "$BASE/local/.github/workflows/vulnerable.yml" <<'EOF'
# BAD: write-all gives this workflow admin-grade access to the repo.
# Any compromised action running here can push, release, comment, delete packages, etc.
# Rewrite to least privilege: contents: read at top-level + per-job escalation
# (with a JUSTIFICATION comment on each elevated key).
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions: write-all

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: run-lint
        run: echo "running lint..."

  comment-pr:
    if: github.event_name == 'pull_request'
    needs: lint
    runs-on: ubuntu-latest
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
    steps:
      - uses: actions/checkout@v4
      - name: draft-release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          echo "would call: gh release create ... --draft"
EOF

cat > "$BASE/local/TASK.md" <<'EOF'
# Task recap

Edit .github/workflows/vulnerable.yml to:

1) Remove `permissions: write-all`.
2) Add top-level:
     permissions:
       contents: read
3) For each job that actually writes:
     - `comment-pr` : needs `pull-requests: write`
     - `publish-draft-release` : needs `contents: write`
   Declare a per-job `permissions:` block including those keys,
   plus a comment on the elevated key (same line or line above)
   whose text contains "justif" (as in "JUSTIFICATION" / "Justificación").
4) `lint` should have NO per-job permissions block (inherit top-level).

Validate:
  MODE=local bash tests/validate.sh /tmp/gha-05-restrict-github-token
EOF

echo "== bootstrap OK ($MODE) =="
echo "Working dir: $BASE/local"
echo "Open .github/workflows/vulnerable.yml and harden it per TASK.md."
