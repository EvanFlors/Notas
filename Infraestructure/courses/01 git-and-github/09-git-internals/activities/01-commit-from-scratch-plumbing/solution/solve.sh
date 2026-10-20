#!/usr/bin/env bash
# Reference solution for gh-09-01-commit-from-scratch-plumbing.
# Builds two chained commits using ONLY plumbing commands.
# Students should NOT run this before trying themselves.
set -euo pipefail

BASE="${1:-/tmp/plumbing-lab}"

if [ ! -d "$BASE/.git" ]; then
  echo "FAIL: $BASE is not a git repo. Run starter/setup-lab.sh first."
  exit 1
fi

cd "$BASE"

echo "---- Commit 1: init: hello ----"
BLOB1=$(printf 'hello\n' | git hash-object --stdin -w)
echo "BLOB1 (hello.txt) = $BLOB1"

TREE1=$(printf '%s %s %s\t%s\n' 100644 blob "$BLOB1" hello.txt | git mktree)
echo "TREE1 = $TREE1"

COMMIT1=$(echo "init: hello" | git commit-tree "$TREE1")
echo "COMMIT1 = $COMMIT1"

git update-ref refs/heads/main "$COMMIT1"

echo
echo "---- Commit 2: feat: add greeter ----"
BLOB2=$(printf '#!/bin/sh\necho hello\n' | git hash-object --stdin -w)
echo "BLOB2 (greeter.sh) = $BLOB2"

TREE2=$(printf '%s %s %s\t%s\n%s %s %s\t%s\n' \
          100644 blob "$BLOB1" hello.txt \
          100755 blob "$BLOB2" greeter.sh | git mktree)
echo "TREE2 = $TREE2"

COMMIT2=$(echo "feat: add greeter" | git commit-tree "$TREE2" -p "$COMMIT1")
echo "COMMIT2 = $COMMIT2"

git update-ref refs/heads/main "$COMMIT2"

echo
echo "---- Verification ----"
git log --oneline
echo
git cat-file -p HEAD
echo
git ls-tree HEAD
echo
echo "Done."
