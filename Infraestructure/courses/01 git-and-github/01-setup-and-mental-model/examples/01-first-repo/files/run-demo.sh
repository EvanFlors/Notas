#!/usr/bin/env bash
# Reproducible demo: observe Git objects appear during init → add → commit.
# Safe to run multiple times. Uses /tmp/git-demo as scratch dir.
set -euo pipefail

DEMO_DIR="/tmp/git-demo"

echo "==> Resetting $DEMO_DIR"
rm -rf "$DEMO_DIR"
mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

echo
echo "==> git init"
git init -b main
ls -la .git/
cat .git/HEAD
echo "objects/ now contains only info/ and pack/:"
ls .git/objects/

echo
echo "==> echo contents > saludo.txt"
echo "Hola, Git" > saludo.txt
git status

echo
echo "==> git add saludo.txt (creates a BLOB)"
git add saludo.txt
echo "Files under .git/objects/ now:"
find .git/objects -type f | sort
HASH_BLOB=$(git hash-object saludo.txt)
echo "Blob hash: $HASH_BLOB"
echo "Type:   $(git cat-file -t "$HASH_BLOB")"
echo "Content: $(git cat-file -p "$HASH_BLOB")"

echo
echo "==> git commit (creates a TREE and a COMMIT)"
git -c user.name=Demo -c user.email=demo@example.com commit -m "primer commit"
echo "Files under .git/objects/ now:"
find .git/objects -type f | sort

HASH_COMMIT=$(git rev-parse HEAD)
HASH_TREE=$(git rev-parse 'HEAD^{tree}')
echo "Commit hash: $HASH_COMMIT"
echo "Tree hash:   $HASH_TREE"

echo
echo "==> cat-file commit"
git cat-file -p "$HASH_COMMIT"

echo
echo "==> cat-file tree"
git cat-file -p "$HASH_TREE"

echo
echo "==> .git/refs/heads/main (the ref IS a file with a hash):"
cat .git/refs/heads/main

echo
echo "==> git log --oneline"
git log --oneline

echo
echo "==> Done. Cleanup: rm -rf $DEMO_DIR"
