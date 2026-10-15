#!/usr/bin/env bash
# Build two chained commits using only plumbing commands.
# No `git add`, no `git commit`. Just hash-object, mktree, commit-tree, update-ref.
set -euo pipefail

DEMO="${1:-/tmp/plumb-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init -q -b main
git config user.name  "Plumber"
git config user.email "plumber@example.com"

echo "---- First commit (initial) ----"
BLOB1=$(echo "hello world" | git hash-object --stdin -w)
echo "blob1 = $BLOB1"

TREE1=$(printf '%s %s %s\t%s\n' 100644 blob "$BLOB1" hello.txt | git mktree)
echo "tree1 = $TREE1"

COMMIT1=$(echo "initial commit (plumbing)" | git commit-tree "$TREE1")
echo "commit1 = $COMMIT1"

git update-ref refs/heads/main "$COMMIT1"

echo
echo "---- Second commit (chained) ----"
BLOB2=$(printf 'line1\nline2\n' | git hash-object --stdin -w)
echo "blob2 = $BLOB2"

TREE2=$(printf '%s %s %s\t%s\n%s %s %s\t%s\n' \
          100644 blob "$BLOB1" hello.txt \
          100644 blob "$BLOB2" notes.txt | git mktree)
echo "tree2 = $TREE2"

COMMIT2=$(echo "add notes.txt" | git commit-tree "$TREE2" -p "$COMMIT1")
echo "commit2 = $COMMIT2"

git update-ref refs/heads/main "$COMMIT2"

echo
echo "---- Materialize working tree ----"
# The working tree is still empty — the index is out of sync with HEAD.
# `git reset --hard HEAD` syncs index + working tree from HEAD's tree.
git reset --hard HEAD >/dev/null
ls

echo
echo "---- git log --oneline ----"
git log --oneline

echo
echo "---- cat-file -p HEAD ----"
git cat-file -p HEAD

echo
echo "Done. Repo at $DEMO"
echo "Cleanup: rm -rf $DEMO"
