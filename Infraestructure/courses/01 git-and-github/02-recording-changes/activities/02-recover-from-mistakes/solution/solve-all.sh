#!/usr/bin/env bash
# Reference solution for gh-02-02-recover-from-mistakes.
# Solves all 4 scenarios. Students should NOT run this before trying themselves.
#
# Usage: ./solve-all.sh [BASE_DIR]
set -euo pipefail

BASE="${1:-/tmp/recover}"

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run starter/build-broken-repos.sh first."
  exit 1
fi

############################################################
# Scenario 1
#   Recover lost WIP commit using reflog.
############################################################
echo "---- Scenario 1 ----"
cd "$BASE/scenario-1"

# Find the lost commit hash in reflog
LOST_HASH=$(git reflog --format='%H %gs' \
  | awk '/commit: WIP: experimentos/{print $1; exit}')
if [ -z "$LOST_HASH" ]; then
  echo "ERROR: could not find lost commit in reflog"
  exit 1
fi
echo "Found lost commit: $LOST_HASH"

# Simplest recovery: cherry-pick it on top of current main
git cherry-pick "$LOST_HASH"
echo "Recovered. git log:"
git log --oneline main | head -5
echo

############################################################
# Scenario 2
#   Move the 'feat: add dark mode' commit from main to feature/dark-mode.
############################################################
echo "---- Scenario 2 ----"
cd "$BASE/scenario-2"

# Create feature branch pointing to the current tip (which has the feat)
# then reset main back to the previous commit.
# main currently is: docs: scenario brief -> feat: add dark mode -> init: base
# We want:
#   feature/dark-mode:  feat: add dark mode  (reachable from here)
#   main:               init: base            (feat NOT in log)

# Find the hashes
FEAT_HASH=$(git log main --format='%H %s' | awk '/^[0-9a-f]+ feat: add dark mode$/{print $1; exit}')
BASE_HASH=$(git log main --format='%H %s' | awk '/^[0-9a-f]+ init: base$/{print $1; exit}')

# Create feature branch at the feat commit
git branch feature/dark-mode "$FEAT_HASH"

# Reset main to init: base (drops both docs: scenario brief AND feat)
git checkout main -q
git reset --hard "$BASE_HASH"

echo "main:"
git log --oneline main
echo "feature/dark-mode:"
git log --oneline feature/dark-mode
echo

############################################################
# Scenario 3
#   Remove secrets.env from the last commit, add gitignore.
############################################################
echo "---- Scenario 3 ----"
cd "$BASE/scenario-3"

# Strategy: soft-reset the last commit, unstage + delete secrets.env,
# add gitignore, re-commit.
git reset --soft HEAD~1
git restore --staged secrets.env 2>/dev/null || true
rm -f secrets.env

# Make sure .gitignore exists and contains the line
touch .gitignore
if ! grep -qx 'secrets.env' .gitignore; then
  echo 'secrets.env' >> .gitignore
fi
git add .gitignore
git commit -q -m "feat: add deploy script (no secrets)"

echo "git log:"
git log --oneline
echo "secrets.env in any tree?"
git log --all --name-only --pretty=format: | sort -u | grep '^secrets.env$' || echo "(none)"
echo

############################################################
# Scenario 4
#   Split last commit (two intents) into two atomic commits.
############################################################
echo "---- Scenario 4 ----"
cd "$BASE/scenario-4"

# chore: cleanup is the one BEFORE "docs: scenario brief"
# Repo log is: docs: scenario brief -> chore: cleanup -> init: project
# We want to KEEP docs: scenario brief if desired? The validator only checks
# that 'chore: cleanup' is gone and the two new commits exist with correct scope.
# Simplest: soft-reset two commits (docs + cleanup), then rebuild bottom-up:
#   1) stage only app.py change -> commit "chore: remove done TODO"
#   2) stage only VERSION change -> commit "chore: bump version to 0.2.0"
#   3) re-create docs: scenario brief

# Capture docs README content first
DOCS_README="$(cat README.md 2>/dev/null || true)"

git reset --mixed HEAD~2

# At this point: HEAD is 'init: project'; working tree has:
#   app.py (no TODO), VERSION 0.2.0, README.md (the brief)
# All appear modified/new in status.

# Commit 1: app.py (TODO removal) only
git add app.py
git commit -q -m "chore: remove done TODO"

# Commit 2: VERSION bump only
git add VERSION
git commit -q -m "chore: bump version to 0.2.0"

# Re-add README (scenario brief) as a docs commit
git add README.md
git commit -q -m "docs: scenario brief"

echo "git log:"
git log --oneline
echo

echo "All scenarios solved."
