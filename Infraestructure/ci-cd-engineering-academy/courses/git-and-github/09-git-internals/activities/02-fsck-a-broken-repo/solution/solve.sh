#!/usr/bin/env bash
# Reference solution for gh-09-02-fsck-a-broken-repo.
# Recovers the missing blob by using backup/ as an alternate, consolidates
# into broken/ with repack, and removes the alternate.
set -euo pipefail

BASE="${1:-/tmp/fsck-lab}"

if [ ! -d "$BASE/broken/.git" ] || [ ! -d "$BASE/backup/.git" ]; then
  echo "FAIL: $BASE is not set up. Run starter/build-broken-repo.sh first."
  exit 1
fi

echo "---- Step 1: diagnose ----"
git -C "$BASE/broken" fsck --full 2>&1 | head -20 || true
echo

MISSING="$(cat "$BASE/MISSING_HASH.txt")"
echo "Missing blob: $MISSING"
echo

echo "---- Step 2: add backup as alternate ----"
mkdir -p "$BASE/broken/.git/objects/info"
echo "$BASE/backup/.git/objects" > "$BASE/broken/.git/objects/info/alternates"

echo "---- Step 3: verify fsck is now clean ----"
git -C "$BASE/broken" fsck --full 2>&1 | head -5 || true
echo

echo "---- Step 4: consolidate objects into broken/ (repack -ad) ----"
git -C "$BASE/broken" repack -ad

echo "---- Step 5: remove alternate ----"
rm -f "$BASE/broken/.git/objects/info/alternates"

echo "---- Step 6: verify the blob is now physically in broken/ ----"
if git -C "$BASE/broken" cat-file -e "$MISSING"; then
  echo "OK: blob $MISSING is reachable in broken/ without alternate."
else
  echo "FAIL: blob still not reachable."
  exit 1
fi

echo
echo "---- Final fsck ----"
git -C "$BASE/broken" fsck --full

echo
echo "Done. broken/ is standalone again."
