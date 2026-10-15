#!/usr/bin/env bash
# Validator for gh-09-02-fsck-a-broken-repo.
#
# Checks that:
#   1) broken/.git/objects/info/alternates does NOT exist.
#   2) The previously-deleted blob is reachable in broken/ WITHOUT the backup.
#   3) `git fsck --full` is clean in broken/ WITHOUT the backup.
#
# To prove (2) and (3), the validator temporarily renames backup/ to backup.hidden/
# so that any lingering alternate pointing to it would break — and then restores.
#
# No `set -o pipefail`: some checks grep-match early on git output and SIGPIPE
# would spuriously fail them.

BASE="${1:-${BASE_DIR:-/tmp/fsck-lab}}"
passed=0
failed=0
report=""

fail() { report+="FAIL: $1\n"; failed=$((failed+1)); }
pass() { report+="OK:   $1\n"; passed=$((passed+1)); }

if [ ! -d "$BASE/broken/.git" ]; then
  echo "FAIL: $BASE/broken not found. Run starter/build-broken-repo.sh first."
  exit 1
fi
if [ ! -f "$BASE/MISSING_HASH.txt" ]; then
  echo "FAIL: $BASE/MISSING_HASH.txt not found. Re-run starter."
  exit 1
fi

MISSING="$(cat "$BASE/MISSING_HASH.txt")"

# 1) Alternates file must be gone
if [ -f "$BASE/broken/.git/objects/info/alternates" ]; then
  fail "broken/.git/objects/info/alternates still exists (student forgot to remove it)"
else
  pass "no alternates file in broken/"
fi

# 2) Backup must still exist and be untouched (we check: still has the blob)
if [ ! -d "$BASE/backup/.git" ]; then
  fail "backup/ is missing (student destroyed the reference repo?)"
else
  if git -C "$BASE/backup" cat-file -e "$MISSING" 2>/dev/null; then
    pass "backup/ is still intact (not modified)"
  else
    fail "backup/ no longer has the reference blob (student mutated it?)"
  fi
fi

# 3) Hide backup to force broken/ to stand on its own
HIDDEN=""
if [ -d "$BASE/backup" ]; then
  HIDDEN="$BASE/backup.hidden.$$"
  mv "$BASE/backup" "$HIDDEN"
fi

restore_backup() {
  if [ -n "$HIDDEN" ] && [ -d "$HIDDEN" ]; then
    mv "$HIDDEN" "$BASE/backup"
  fi
}
trap restore_backup EXIT

# 4) The blob must be reachable in broken/ without the backup
if git -C "$BASE/broken" cat-file -e "$MISSING" 2>/dev/null; then
  pass "blob $MISSING is reachable in broken/ without the backup"
else
  fail "blob $MISSING is NOT reachable in broken/ once backup is hidden (did you run 'git repack -ad' or copy the object before removing the alternate?)"
fi

# 5) fsck --full should be clean, no missing / broken link
FSCK_OUT="$(git -C "$BASE/broken" fsck --full 2>&1 || true)"
if echo "$FSCK_OUT" | grep -qE 'missing |broken link'; then
  fail "git fsck --full still reports missing or broken links:"
  report+="----\n$FSCK_OUT\n----\n"
else
  pass "git fsck --full is clean in broken/"
fi

# 6) HEAD traversal works — can we checkout the file that used to be missing?
TMPWT="$BASE/broken-check-worktree.$$"
if git -C "$BASE/broken" worktree add --quiet "$TMPWT" HEAD~1 2>/dev/null; then
  if [ -f "$TMPWT/critical.conf" ] && grep -q "feature_z = experimental" "$TMPWT/critical.conf"; then
    pass "HEAD~1 checks out and critical.conf contents are recovered"
  else
    fail "HEAD~1 checked out but critical.conf is missing or wrong"
  fi
  git -C "$BASE/broken" worktree remove --force "$TMPWT" 2>/dev/null || rm -rf "$TMPWT"
else
  fail "cannot create worktree at HEAD~1 — history still broken"
  rm -rf "$TMPWT"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed passed, $failed failed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
echo "OK"
exit 0
