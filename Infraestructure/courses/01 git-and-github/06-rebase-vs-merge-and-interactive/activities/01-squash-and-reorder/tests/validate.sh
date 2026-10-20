#!/usr/bin/env bash
# Validate gh-06-01-squash-and-reorder:
#   - branch feature/payments
#   - exactly 2 commits on top of "init: payments module scaffold"
#   - exact subjects
#   - commit scopes: feat touches payments.py (not tests/), test touches only tests/
#   - final content of payments.py has license header and def refund(
#   - clean working tree
#
# No `set -o pipefail`: many checks use `git log | grep -q` which gets SIGPIPE.

REPO="${1:-${REPO_DIR:-/tmp/squash-and-reorder}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Build with starter/build-messy-branch.sh"
  exit 1
fi
cd "$REPO"

# Branch
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$branch" = "feature/payments" ]; then
  echo "  OK   HEAD on feature/payments"
else
  echo "  FAIL HEAD on '$branch' (expected feature/payments)"
  fail=$((fail+1))
fi

# Working tree clean
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean:"
  git status --short
  fail=$((fail+1))
fi

# Find base commit
base="$(git log --format='%H %s' | awk '/init: payments module scaffold$/{print $1; exit}')"
if [ -z "$base" ]; then
  echo "  FAIL base commit 'init: payments module scaffold' not found"
  exit 1
fi
echo "  OK   base commit present"

# Exactly 2 new commits
count="$(git rev-list --count "$base..HEAD")"
if [ "$count" = "2" ]; then
  echo "  OK   exactly 2 commits on top of base"
else
  echo "  FAIL expected exactly 2 commits on top of base; got $count"
  fail=$((fail+1))
fi

# Subjects (en orden: viejo -> nuevo son el 2do y 1ro de git log)
subj_top="$(git log -n1 --format='%s' HEAD)"
subj_mid="$(git log -n1 --format='%s' HEAD~1 2>/dev/null || echo '')"

if [ "$subj_top" = "test(payments): cover refund processor" ] \
   && [ "$subj_mid" = "feat(payments): add refund processor" ]; then
  echo "  OK   subjects exactly as expected"
else
  echo "  FAIL subjects mismatch"
  echo "       HEAD:   '$subj_top'"
  echo "       HEAD~1: '$subj_mid'"
  echo "       expected HEAD~1 = 'feat(payments): add refund processor'"
  echo "       expected HEAD   = 'test(payments): cover refund processor'"
  fail=$((fail+1))
fi

# Scope check: feat commit touches payments.py only (not tests/)
feat_hash="$(git log --format='%H %s' "$base..HEAD" | awk '/feat\(payments\): add refund processor$/{print $1; exit}')"
test_hash="$(git log --format='%H %s' "$base..HEAD" | awk '/test\(payments\): cover refund processor$/{print $1; exit}')"

if [ -n "$feat_hash" ]; then
  feat_files="$(git show --name-only --pretty=format: "$feat_hash" | sed '/^$/d' | sort -u | tr '\n' ' ')"
  # Must include payments.py and NOT include anything under tests/
  if echo "$feat_files" | grep -q 'payments.py' && ! echo "$feat_files" | grep -q 'tests/'; then
    echo "  OK   feat commit scoped to payments.py (no tests/)"
  else
    echo "  FAIL feat commit files = '$feat_files' (expected to include payments.py and exclude tests/)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL could not find feat commit by subject"
  fail=$((fail+1))
fi

if [ -n "$test_hash" ]; then
  test_files="$(git show --name-only --pretty=format: "$test_hash" | sed '/^$/d' | sort -u | tr '\n' ' ')"
  # Must contain tests/test_payments.py and nothing else
  norm="$(echo "$test_files" | tr -s ' ' | sed 's/ *$//')"
  if [ "$norm" = "tests/test_payments.py" ]; then
    echo "  OK   test commit scoped to tests/test_payments.py only"
  else
    echo "  FAIL test commit files = '$test_files' (expected only 'tests/test_payments.py')"
    fail=$((fail+1))
  fi
else
  echo "  FAIL could not find test commit by subject"
  fail=$((fail+1))
fi

# Content checks
if [ -f payments.py ]; then
  first_line="$(head -n1 payments.py)"
  if echo "$first_line" | grep -q '^# Copyright'; then
    echo "  OK   payments.py starts with license header"
  else
    echo "  FAIL payments.py first line is '$first_line' (expected '# Copyright ...')"
    fail=$((fail+1))
  fi
  if grep -q '^def refund(' payments.py; then
    echo "  OK   payments.py defines refund("
  else
    echo "  FAIL payments.py does not define 'def refund('"
    fail=$((fail+1))
  fi
  if grep -q '"accepted"' payments.py; then
    echo "  OK   payments.py returns accepted (typo fixed)"
  else
    echo "  FAIL payments.py does not return 'accepted'"
    fail=$((fail+1))
  fi
else
  echo "  FAIL payments.py missing"
  fail=$((fail+1))
fi

if [ -f tests/test_payments.py ]; then
  if grep -q 'test_refund_accepted' tests/test_payments.py; then
    echo "  OK   tests/test_payments.py has test_refund_accepted"
  else
    echo "  FAIL tests/test_payments.py does not contain test_refund_accepted"
    fail=$((fail+1))
  fi
else
  echo "  FAIL tests/test_payments.py missing"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
