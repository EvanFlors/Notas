#!/usr/bin/env bash
# Reproduces three merge scenarios side by side under $BASE/case-{a,b,c}.
# Prints `git log --graph` of each to compare the resulting DAG.
set -euo pipefail

BASE="${1:-/tmp/ff-vs-merge}"
rm -rf "$BASE"
mkdir -p "$BASE"

setup_common() {
  git init -q -b main
  git config user.name  "Demo"
  git config user.email "demo@example.com"
  echo "# Project" > README.md
  git add README.md
  git commit -q -m "init: README"
}

############################################################
# Case A: fast-forward
#   main did not advance since branch-off.
#   Default merge → FF, zero new commits.
############################################################
A="$BASE/case-a"
mkdir -p "$A" && cd "$A"
setup_common

git switch -q -c feature/x
echo "feature line" >> README.md
git add README.md
git commit -q -m "feat: F1"

git switch -q main
git merge -q feature/x    # fast-forward

echo "============================================"
echo "CASE A — fast-forward (default)"
echo "============================================"
git log --graph --oneline --all --decorate
echo

############################################################
# Case B: --no-ff forces a merge commit
#   Same scenario as A, but we force a merge commit for visibility.
############################################################
B="$BASE/case-b"
mkdir -p "$B" && cd "$B"
setup_common

git switch -q -c feature/x
echo "feature line" >> README.md
git add README.md
git commit -q -m "feat: F1"

git switch -q main
git merge -q --no-ff -m "Merge branch 'feature/x'" feature/x

echo "============================================"
echo "CASE B — --no-ff (forced merge commit)"
echo "============================================"
git log --graph --oneline --all --decorate
echo

############################################################
# Case C: real 3-way merge
#   main also advances before merging → cannot FF.
############################################################
C="$BASE/case-c"
mkdir -p "$C" && cd "$C"
setup_common

git switch -q -c feature/x
echo "feature line" >> README.md
git add README.md
git commit -q -m "feat: F1"

git switch -q main
# Modify a DIFFERENT file so the 3-way merge is clean (no conflict).
echo "notes on main" > NOTES.md
git add NOTES.md
git commit -q -m "docs: C1 in main"

git merge -q --no-edit feature/x    # real 3-way merge, no conflicts

echo "============================================"
echo "CASE C — real 3-way merge (main also advanced)"
echo "============================================"
git log --graph --oneline --all --decorate
echo

echo "Done. Explore each case under $BASE/case-{a,b,c}"
