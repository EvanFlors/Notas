#!/usr/bin/env bash
# Demo automatizado de rebase --onto.
set -euo pipefail

REPO="${1:-/tmp/onto-demo}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "v0.1" > VERSION
git add VERSION
git commit -q -m "chore: initial"

# release/1.0
git switch -q -c release/1.0
echo "release notes 1.0" > RELEASE_NOTES.md
git add RELEASE_NOTES.md
git commit -q -m "docs: release notes 1.0"
echo "v1.0" > VERSION
git commit -q -am "chore: bump to 1.0"

# feature/dashboard DESDE release/1.0 (por error)
git switch -q -c feature/dashboard
mkdir -p dashboard
echo "<h1>Dashboard</h1>" > dashboard/index.html
git add dashboard/index.html
git commit -q -m "feat(dashboard): scaffold"

echo "console.log(\"dashboard\");" > dashboard/app.js
git add dashboard/app.js
git commit -q -m "feat(dashboard): add app.js"

echo "body { font: sans-serif; }" > dashboard/styles.css
git add dashboard/styles.css
git commit -q -m "feat(dashboard): add styles"

# main avanza
git switch -q main
echo "v0.2" > VERSION
git commit -q -am "chore: bump to 0.2 (unreleased)"

echo
echo "===== ANTES ====="
git log --all --graph --oneline --decorate
echo

# Fix:
git switch -q feature/dashboard
git rebase --onto main release/1.0

echo
echo "===== DESPUES ====="
git log --all --graph --oneline --decorate
echo
echo "feature/dashboard ahora cuelga de main con 3 commits propios."
