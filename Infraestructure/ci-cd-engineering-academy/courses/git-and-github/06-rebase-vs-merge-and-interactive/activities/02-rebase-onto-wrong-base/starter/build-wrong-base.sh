#!/usr/bin/env bash
# Build a repo where feature/dashboard was branched from release/1.0 by mistake,
# and main has advanced independently.
set -euo pipefail

REPO="${1:-/tmp/rebase-onto-wrong-base}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

# --- Common base ---
echo "v0.1" > VERSION
git add VERSION
git commit -q -m "chore: initial"

# --- release/1.0: branch and commit release-only stuff ---
git switch -q -c release/1.0
cat > RELEASE_NOTES.md <<'EOF'
# Release 1.0

- Initial public release.
EOF
git add RELEASE_NOTES.md
git commit -q -m "docs: release notes 1.0"

echo "v1.0" > VERSION
git commit -q -am "chore: bump to 1.0"

# --- feature/dashboard FROM release/1.0 (wrong!) ---
git switch -q -c feature/dashboard
mkdir -p dashboard
cat > dashboard/index.html <<'EOF'
<!doctype html>
<h1>Dashboard</h1>
EOF
git add dashboard/index.html
git commit -q -m "feat(dashboard): scaffold"

cat > dashboard/app.js <<'EOF'
console.log("dashboard loaded");
EOF
git add dashboard/app.js
git commit -q -m "feat(dashboard): add app.js"

cat > dashboard/styles.css <<'EOF'
body { font-family: sans-serif; }
EOF
git add dashboard/styles.css
git commit -q -m "feat(dashboard): add styles"

# --- main advances independently ---
git switch -q main
echo "v0.2" > VERSION
git commit -q -am "chore: bump to 0.2 (unreleased)"

# Return to feature branch so student starts there
git switch -q feature/dashboard

# Snapshot ref tips so the validator can check main/release didn't move.
mkdir -p .git/activity-meta
git rev-parse main        > .git/activity-meta/main.sha
git rev-parse release/1.0 > .git/activity-meta/release-1.0.sha

echo
echo "Repo listo en: $REPO"
echo "Rama actual:  $(git symbolic-ref --short HEAD)"
echo
git log --all --graph --oneline --decorate
echo
echo "Mueve feature/dashboard para que cuelgue de main."
echo "Lee README.md para el contexto. Valida con tests/validate.sh."
