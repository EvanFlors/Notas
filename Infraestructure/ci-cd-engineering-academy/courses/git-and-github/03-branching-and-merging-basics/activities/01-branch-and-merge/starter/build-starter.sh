#!/usr/bin/env bash
# Builds the starter repo for gh-03-01-branch-and-merge.
# Clean repo with 2 commits on main; a typo intentionally present in notes.md.
set -euo pipefail

BASE="${1:-/tmp/branch-merge}"
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
# Encourage reading the base in conflict markers (Task 3).
git config merge.conflictStyle diff3

cat > notes.md <<'EOF'
# Nootes

Personal engineering notes.
EOF
git add notes.md
git commit -q -m "init: notes"

cat > notes.md <<'EOF'
# Nootes

Personal engineering notes.

## Outline

- TODO
EOF
git add notes.md
git commit -q -m "docs: add outline"

echo "Starter ready at: $BASE"
echo
git log --oneline
echo
git status
