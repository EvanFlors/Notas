#!/usr/bin/env bash
# Builds a broken repo scenario for gh-09-02-fsck-a-broken-repo.
#
# Produces:
#   $BASE/backup/   -> healthy reference repo (3 commits, loose objects, no pack)
#   $BASE/broken/   -> same history BUT with one blob loose object missing
#   $BASE/MISSING_HASH.txt  -> the blob hash that was deleted (reference)
#
# The student is told backup/ exists as "another developer's clone" — their
# task is to use it as an alternate to recover.
set -euo pipefail

BASE="${1:-/tmp/fsck-lab}"
rm -rf "$BASE"
mkdir -p "$BASE"

make_identity() {
  git config user.name  "Student"
  git config user.email "student@example.com"
  git config commit.gpgsign false
}

############################################################
# 1) Build the healthy "backup" repo (reference)
############################################################
cd "$BASE"
git init -q -b main backup
cd backup
make_identity

cat > README.md <<'EOF'
# Project Phoenix

A tiny demo repo used to practice `git fsck` and alternates-based recovery.
EOF
git add README.md
git commit -q -m "init: project phoenix"

cat > critical.conf <<'EOF'
# critical.conf — do not lose me
timeout = 30
retries = 5
mode = production
feature_x = on
feature_y = off
feature_z = experimental
EOF
git add critical.conf
git commit -q -m "feat: add critical.conf"

echo "unused line" >> README.md
git add README.md
git commit -q -m "docs: tweak README"

# Important: keep the backup fully LOOSE so the student can read individual
# objects from it. If we gc'd here, the broken clone would need to copy from
# a pack, which still works, but we want the simplest teaching path.

cd "$BASE"

############################################################
# 2) Copy it to broken/ (preserves loose objects verbatim),
#    then corrupt by removing one specific blob.
############################################################
cp -R backup broken

cd broken
make_identity

# Find the blob hash of critical.conf (its content) in the healthy repo
MISSING_BLOB=$(git rev-parse HEAD~1:critical.conf)

# Record it for the student
echo "$MISSING_BLOB" > "$BASE/MISSING_HASH.txt"

# Delete the specific loose object from broken/ ONLY
TARGET=".git/objects/${MISSING_BLOB:0:2}/${MISSING_BLOB:2}"
if [ ! -f "$TARGET" ]; then
  echo "ERROR: expected loose object $TARGET not found in broken/." >&2
  echo "       (object layout differs from expected; investigate before continuing.)" >&2
  exit 1
fi
rm -f "$TARGET"

# Remove parent dir if empty (cosmetic)
rmdir ".git/objects/${MISSING_BLOB:0:2}" 2>/dev/null || true

cd "$BASE"

############################################################
# 3) Scenario brief
############################################################
cat > README.md <<EOF
# Scenario: Project Phoenix is broken

You have two directories here:

  broken/   — the production checkout. Something is wrong with it.
  backup/   — a teammate's healthy clone of the SAME repo. Fully intact.

A loose object was deleted from \`broken/.git/objects/\` by an accidental
\`rm -rf\`. The repo is now partially corrupt.

Your mission:
  1. Diagnose with \`git -C broken fsck --full\` and read the output carefully.
  2. Recover the missing object(s) using \`backup/\` as a Git **alternate**.
  3. Consolidate the recovered object(s) into \`broken/\` so it no longer
     depends on \`backup/\` (think: \`git repack -ad\` or copying the object).
  4. Remove the alternate file.
  5. Confirm \`git -C broken fsck --full\` is clean.

For reference, the deleted blob hash is in: MISSING_HASH.txt
(you shouldn't need to open it to solve — \`fsck\` will tell you.)

When done, run:
  bash tests/validate.sh "$BASE"
EOF

echo "Broken-repo lab ready at: $BASE"
echo
echo "Directory listing:"
ls -1 "$BASE"
echo
echo "Deleted blob hash: $(cat "$BASE/MISSING_HASH.txt")"
echo
echo "Now go to the activity README and solve."
