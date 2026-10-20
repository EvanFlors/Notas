#!/usr/bin/env bash
# Bootstrap for gh-05-01-create-repo-and-push.
#
# MODE=local (default): creates a bare "origin" repo + an empty working repo
# with git initialized, 'main' branch, 1 base commit, 'origin' remote configured.
# The student edits files and runs `git push -u origin main`.
#
# MODE=live: only creates the working repo; the student runs `gh repo create`
# to create the actual remote on GitHub.
set -euo pipefail

BASE="${1:-/tmp/create-repo-and-push}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE"

LOCAL="$BASE/local"
mkdir -p "$LOCAL"
cd "$LOCAL"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# Placeholder files so there is something to overwrite
cat > README.md <<'EOF'
# PLACEHOLDER README — replace me

Students: replace this file to fulfill the acceptance criteria.
Required headings (exact):
  # <project title>
  ## Instalación
  ## Uso
  ## Licencia
EOF

cat > .gitignore <<'EOF'
# PLACEHOLDER — replace or extend as needed
EOF

# No LICENSE on purpose; student must add it.

git add .
git commit -q -m "chore: scaffold placeholder (base commit)"

if [ "$MODE" = "local" ]; then
  echo "== MODE=local: creating bare origin and wiring remote =="
  git init -q --bare "$BASE/origin.git"
  git remote add origin "$BASE/origin.git"
  echo
  echo "Working repo:   $LOCAL"
  echo "Simulated origin (bare): $BASE/origin.git"
  echo
  echo "Next:"
  echo "  cd $LOCAL"
  echo "  # edit README.md, add LICENSE, improve .gitignore"
  echo "  git add . && git commit -m 'chore: initial public skeleton'"
  echo "  git push -u origin main"
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
  echo "Working repo: $LOCAL"
  echo "No 'origin' remote wired yet; after editing & committing, run:"
  echo "  cd $LOCAL"
  echo "  gh repo create <name> --public --source=. --remote=origin --push"
else
  echo "ERROR: unknown MODE='$MODE' (use 'local' or 'live')" >&2
  exit 2
fi
