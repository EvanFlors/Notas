#!/usr/bin/env bash
# Reference solution for gha-01-01-first-workflow (MODE=local).
# Builds a repo under $BASE/repo that matches all acceptance criteria.

set -euo pipefail

BASE="${1:-/tmp/gha-01-first-workflow}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Reuse the starter bootstrap so student+solution exercise the same path.
bash "$SCRIPT_DIR/starter/bootstrap.sh" "$BASE" >/dev/null

REPO="$BASE/repo"
cd "$REPO"

cat > .github/workflows/ci.yml <<'EOF'
# .github/workflows/ci.yml
name: ci

on:
  push:
  pull_request:

jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Info del evento
        run: |
          echo "repo:  $GITHUB_REPOSITORY"
          echo "sha:   $GITHUB_SHA"
          echo "event: $GITHUB_EVENT_NAME"
          echo "actor: $GITHUB_ACTOR"
          echo "--- workspace ---"
          ls -la
EOF

git add .github/workflows/ci.yml
git commit -q -m "ci: add first workflow (push + pull_request)"

echo "Solution built at: $REPO"
git log --oneline
