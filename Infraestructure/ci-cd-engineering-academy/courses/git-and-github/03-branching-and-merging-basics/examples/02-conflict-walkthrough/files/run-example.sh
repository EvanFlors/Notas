#!/usr/bin/env bash
# Builds a minimal conflicting-merge scenario and LEAVES IT in conflict state
# so the student can explore `git status`, markers, and the 3 stages.
set -euo pipefail

DEMO="${1:-/tmp/conflict-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"
# Show the base (common ancestor) in conflict markers:
git config merge.conflictStyle diff3

# Base commit on main
printf 'greeting = hello\n' > config.txt
git add config.txt
git commit -q -m "init: config"

# Divergent change on feature/greeting
git switch -q -c feature/greeting
printf 'greeting = hi\n' > config.txt
git add config.txt
git commit -q -m "feat: use 'hi'"

# Divergent change on main (same line, different value)
git switch -q main
printf 'greeting = hola\n' > config.txt
git add config.txt
git commit -q -m "feat: use 'hola'"

# Attempt the merge → will conflict. We allow non-zero exit from merge.
set +e
git merge --no-edit feature/greeting
MERGE_EXIT=$?
set -e

echo
echo "============================================"
echo "Merge exited with code $MERGE_EXIT (expected 1 — conflict)."
echo "============================================"
echo
echo "git status:"
echo "---"
git status
echo "---"
echo
echo "config.txt (with diff3 markers):"
echo "---"
cat config.txt
echo "---"
echo
echo "The 3 stages in the index (base=1, ours=2, theirs=3):"
echo "---"
git ls-files -u
echo "---"
echo
echo "Repo left in conflict state at: $DEMO"
echo "Next steps you can try:"
echo "  cd $DEMO"
echo "  git show :1:config.txt   # base"
echo "  git show :2:config.txt   # ours"
echo "  git show :3:config.txt   # theirs"
echo
echo "Option A — RESOLVE:"
echo "  printf 'greeting = hola, hi\\n' > config.txt"
echo "  git add config.txt && git commit"
echo
echo "Option B — ABORT:"
echo "  git merge --abort"
