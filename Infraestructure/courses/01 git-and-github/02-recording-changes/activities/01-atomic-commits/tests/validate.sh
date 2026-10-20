#!/usr/bin/env bash
# Validate: student produced >=4 atomic commits following Conventional Commits
# on top of the base state, final content matches reference, clean worktree.
set -o pipefail

REPO="${1:-${REPO_DIR:-/tmp/atomic-commits}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Build it first with starter/build-dirty-repo.sh"
  exit 1
fi
cd "$REPO"

# Branch main
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ]; then
  echo "  OK   HEAD on main"
else
  echo "  FAIL HEAD on '$branch' (expected main)"
  fail=$((fail+1))
fi

# Working tree clean
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean. git status:"
  git status --short
  fail=$((fail+1))
fi

# Find the base commit (subject == "init: base state")
base=$(git log --format='%H %s' | awk '/init: base state/{print $1; exit}')
if [ -z "$base" ]; then
  echo "  FAIL base commit 'init: base state' not found. Did you reset?"
  exit 1
fi
echo "  OK   base commit: $base"

# Count new commits on top of base
count_new=$(git rev-list --count "$base..HEAD")
if [ "$count_new" -ge 4 ]; then
  echo "  OK   new commits on top of base: $count_new (>=4)"
else
  echo "  FAIL new commits on top of base: $count_new (expected >=4)"
  fail=$((fail+1))
fi

# All new commit subjects follow Conventional Commits
bad_subject=0
while IFS= read -r subj; do
  if ! [[ "$subj" =~ ^(feat|fix|refactor|test|docs|chore|style|perf|ci|build|revert)(\([a-zA-Z0-9/_-]+\))?(!)?:\ .+ ]]; then
    echo "  FAIL commit subject does not follow Conventional Commits: '$subj'"
    bad_subject=$((bad_subject+1))
  fi
done < <(git log --format='%s' "$base..HEAD")
if [ "$bad_subject" -eq 0 ]; then
  echo "  OK   all new commit subjects are Conventional Commits"
else
  fail=$((fail+bad_subject))
fi

# Final content matches reference (hash of tree HEAD) — reference: solution/final-tree-hash
ref_file="$(dirname "$0")/../solution/expected-content.txt"
if [ ! -f "$ref_file" ]; then
  echo "  WARN reference file not found: $ref_file (skipping content check)"
else
  # Compute hash of concatenated final content
  current=$(cat app/calculator.py app/config.py tests/test_calculator.py | sha256sum | awk '{print $1}')
  expected=$(cat "$ref_file" | sha256sum | awk '{print $1}')
  if [ "$current" = "$expected" ]; then
    echo "  OK   final content matches reference"
  else
    echo "  FAIL final content does not match reference"
    echo "       current  sha256: $current"
    echo "       expected sha256: $expected"
    fail=$((fail+1))
  fi
fi

# At least one of each: fix, refactor, test or feat
for t in fix refactor; do
  if git log --format='%s' "$base..HEAD" | grep -Eq "^${t}(\(|!|:)"; then
    echo "  OK   at least one '${t}:' commit present"
  else
    echo "  FAIL no '${t}:' commit found among new commits"
    fail=$((fail+1))
  fi
done
if git log --format='%s' "$base..HEAD" | grep -Eq "^(feat|test)(\(|!|:)"; then
  echo "  OK   at least one 'feat:' or 'test:' commit present"
else
  echo "  FAIL no 'feat:' or 'test:' commit present"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
