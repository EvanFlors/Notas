#!/usr/bin/env bash
# Bootstrap for gha-06-01-matrix-with-include-exclude.
#
# MODE=local (default): creates a scaffold repo under $BASE/local with a
#   placeholder workflow at .github/workflows/ci.yml. Students edit it to
#   satisfy the acceptance criteria; the validator parses the YAML.
# MODE=live: additionally verifies `gh` is authenticated so the student can
#   push the completed workflow to a real repo and dispatch it.
set -euo pipefail

BASE="${1:-/tmp/gha-06-01}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE/local/.github/workflows"
cd "$BASE/local"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > .github/workflows/ci.yml <<'EOF'
# PLACEHOLDER WORKFLOW — replace me.
#
# You must satisfy ALL acceptance criteria in README.md section 7:
#   - name: ci
#   - on: push + workflow_dispatch
#   - permissions: contents: read
#   - jobs.test with:
#       - runs-on: ${{ matrix.os }}
#       - strategy.fail-fast: false
#       - strategy.matrix with os (>=2), python (>=2),
#         at least one `exclude` entry (with a justifying comment)
#         and at least one `include` entry with `experimental: true`
#       - steps using actions/checkout@v4 and actions/setup-python@v5,
#         and a step with `continue-on-error: ${{ matrix.experimental == true }}`
name: placeholder
on: workflow_dispatch
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo "replace me"
EOF

cat > README-local.md <<'EOF'
# gha-06-01 starter

Edit `.github/workflows/ci.yml`.

Validate with:
    MODE=local bash tests/validate.sh /tmp/gha-06-01
EOF

git add .
git commit -q -m "chore: scaffold placeholder workflow"

if [ "$MODE" = "local" ]; then
  echo "== MODE=local =="
  echo "Working repo: $BASE/local"
  echo "Edit:         $BASE/local/.github/workflows/ci.yml"
  echo "Validate:     MODE=local bash tests/validate.sh $BASE"
elif [ "$MODE" = "live" ]; then
  echo "== MODE=live: verifying gh auth =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' CLI not installed. See https://cli.github.com/" >&2
    exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: 'gh' not authenticated. Run: gh auth login" >&2
    exit 2
  fi
  echo "gh auth OK."
  echo
  echo "After editing the workflow:"
  echo "  cd $BASE/local"
  echo "  git add . && git commit -m 'ci: matrix with include/exclude'"
  echo "  gh repo create <name> --private --source=. --remote=origin --push"
  echo "  gh workflow run ci"
  echo "Then: MODE=live bash tests/validate.sh $BASE"
else
  echo "ERROR: unknown MODE='$MODE' (use 'local' or 'live')" >&2
  exit 2
fi
