#!/usr/bin/env bash
# Build a repo whose growing file is a good delta-compression candidate,
# gc it, and show what the packfile looks like.
set -euo pipefail

DEMO="${1:-/tmp/pack-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"
git config commit.gpgsign false

echo "Creating 30 commits that grow a file line by line..."
for i in $(seq 1 30); do
  printf 'line %02d\n' "$i" >> growing.txt
  git add growing.txt
  git commit -q -m "add line $i"
done

echo
echo "---- BEFORE gc ----"
loose=$(find .git/objects -type f \
         ! -path '.git/objects/pack/*' \
         ! -path '.git/objects/info/*' | wc -l)
echo "loose objects: $loose"
echo "pack dir contents:"
ls .git/objects/pack/ 2>/dev/null || echo "(empty)"

echo
echo "---- Running git gc ----"
git gc --quiet

echo
echo "---- AFTER gc ----"
loose=$(find .git/objects -type f \
         ! -path '.git/objects/pack/*' \
         ! -path '.git/objects/info/*' | wc -l)
echo "loose objects: $loose"
echo "pack dir contents:"
ls .git/objects/pack/

echo
IDX=$(ls .git/objects/pack/pack-*.idx | head -1)
echo "---- verify-pack -v (first 20 lines) ----"
git verify-pack -v "$IDX" | head -20

echo
echo "---- verify-pack summary (tail) ----"
git verify-pack -v "$IDX" | tail -15

echo
echo "Done. Repo at $DEMO"
echo "Cleanup: rm -rf $DEMO"
