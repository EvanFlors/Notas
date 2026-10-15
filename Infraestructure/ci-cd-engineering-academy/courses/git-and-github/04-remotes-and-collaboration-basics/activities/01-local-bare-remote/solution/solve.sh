#!/usr/bin/env bash
# Reference solution for gh-04-01-local-bare-remote.
# Runs ALL 9 README steps non-interactively.
# Students should NOT run this before trying by hand.
#
# Usage: ./solve.sh [BASE_DIR]
set -euo pipefail

BASE="${1:-/tmp/gh-04-bare}"

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run starter/prepare.sh first."
  exit 1
fi

# Step 1: create bare "server"
cd "$BASE"
rm -rf origin.git local other     # clean slate even if partially run before
git init --bare -q -b main origin.git

# Step 2: working repo + connect
mkdir local
cd local
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

echo "# gh-04 lab" > README.md
git add README.md
git commit -q -m "init: project"

git remote add origin "$BASE/origin.git"

# Step 3: first push with -u
git push -qu origin main

# Step 5: second commit + plain push
echo "Second line." >> README.md
git commit -qam "feat: second line"
git push -q

# Step 6: a second clone acts as "someone else"
cd "$BASE"
git clone -q origin.git other
cd other
git config user.name  "Other"
git config user.email "other@example.com"
echo "Third line (other)." >> README.md
git commit -qam "feat: third line"
git push -q

# Step 7+8: back to local, fetch + ff
cd "$BASE/local"
git fetch -q origin
git merge --ff-only -q origin/main

echo
echo "Solved. Final state:"
echo "  bare: $BASE/origin.git"
echo "  local HEAD on main:"
git -C "$BASE/local" log --oneline main
echo "  origin.git refs/heads/main:"
git -C "$BASE/origin.git" log --oneline main
