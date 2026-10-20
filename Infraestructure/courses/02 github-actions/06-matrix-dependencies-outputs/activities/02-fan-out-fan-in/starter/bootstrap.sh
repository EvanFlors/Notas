#!/usr/bin/env bash
# Bootstrap for gha-06-02-fan-out-fan-in.
#
# Creates a scaffold repo under $BASE/local with a placeholder workflow at
# .github/workflows/pipeline.yml. The student replaces it entirely to satisfy
# the acceptance criteria. Solution is NOT revealed in the placeholder.
set -euo pipefail

BASE="${1:-/tmp/gha-06-02}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"
cd "$BASE/local"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > .github/workflows/pipeline.yml <<'EOF'
# PLACEHOLDER WORKFLOW — replace me entirely.
#
# Build a fan-out / fan-in pipeline. See README.md section 7 for the
# acceptance criteria. Do NOT look at solution/ until you've tried it.
name: placeholder
on: workflow_dispatch
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo "replace me"
EOF

git add .
git commit -q -m "chore: scaffold placeholder pipeline"

if [ "$MODE" = "local" ]; then
  echo "== MODE=local =="
  echo "Working repo: $BASE/local"
  echo "Edit:         $BASE/local/.github/workflows/pipeline.yml"
  echo "Validate:     MODE=local bash tests/validate.sh $BASE"
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' CLI not installed." >&2; exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: 'gh' not authenticated. Run: gh auth login" >&2; exit 2
  fi
  echo "gh auth OK. After editing + pushing, run: gh workflow run pipeline"
else
  echo "ERROR: unknown MODE='$MODE' (use 'local' or 'live')" >&2
  exit 2
fi
