#!/usr/bin/env bash
# Bootstrap for gha-01-01-first-workflow.
#
# MODE=local (default): creates /tmp/.../repo as a local git repo with a
# PLACEHOLDER .github/workflows/ci.yml that does NOT yet meet the criteria.
# Student edits it and commits; validator checks structure without GitHub.
#
# MODE=live: same as local, PLUS instructs on `gh repo create` to publish and
# run the workflow for real.
set -euo pipefail

BASE="${1:-/tmp/gha-01-first-workflow}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE"

REPO="$BASE/repo"
mkdir -p "$REPO/.github/workflows"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > README.md <<'EOF'
# gha-01-first-workflow

Repo scratch para la actividad `gha-01-01-first-workflow`.
Reemplaza `.github/workflows/ci.yml` por un workflow que cumpla los criterios
de la actividad.
EOF

cat > .github/workflows/ci.yml <<'EOF'
# PLACEHOLDER — reemplaza este archivo.
#
# Debe cumplir:
#   - name: <algo>
#   - on: { push: ..., pull_request: ... }
#   - jobs: con al menos uno:
#       - runs-on: ubuntu-latest (o ubuntu-22.04 / ubuntu-24.04)
#       - steps:
#           - uses: actions/checkout@v4
#           - run: |
#               echo "repo: $GITHUB_REPOSITORY"
#               echo "sha:  $GITHUB_SHA"
#
# Mientras exista este placeholder, el validador fallará.
name: placeholder
on:
  workflow_dispatch:
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo "replace me"
EOF

git add .
git commit -q -m "chore: scaffold placeholder repo (base commit)"

echo "== Bootstrap OK =="
echo "Working repo:  $REPO"
echo "Workflow file: $REPO/.github/workflows/ci.yml  (PLACEHOLDER)"
echo
echo "Next:"
echo "  1) Edita $REPO/.github/workflows/ci.yml para cumplir los criterios."
echo "  2) cd $REPO && git add . && git commit -m 'ci: add first workflow'"
echo "  3) bash .../tests/validate.sh $BASE   # modo local"

if [ "$MODE" = "live" ]; then
  echo
  echo "== MODE=live: verificando gh auth =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' CLI no instalado. Ver https://cli.github.com/" >&2
    exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: 'gh' no autenticado. Ejecuta: gh auth login" >&2
    exit 2
  fi
  echo "gh auth OK. Después de commitear tu workflow, publica el repo:"
  echo "  cd $REPO"
  echo "  gh repo create gha-01-first-workflow-\$(date +%s) --private --source=. --remote=origin --push"
  echo "Y luego valida con: MODE=live bash .../tests/validate.sh $BASE"
elif [ "$MODE" != "local" ]; then
  echo "WARNING: MODE desconocido '$MODE' (usa 'local' o 'live'); continué como 'local'." >&2
fi
