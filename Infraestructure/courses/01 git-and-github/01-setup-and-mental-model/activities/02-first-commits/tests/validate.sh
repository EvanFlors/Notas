#!/usr/bin/env bash
# Validate: student performed gh-01-02-first-commits correctly.
# Pass REPO_DIR as first arg or set env var; defaults to /tmp/first-commits.

set -o pipefail

REPO="${1:-${REPO_DIR:-/tmp/first-commits}}"
fail=0

echo "== Validating repo at: $REPO =="

if [ ! -d "$REPO" ]; then
  echo "FAIL: directory does not exist: $REPO"
  exit 1
fi
cd "$REPO"

if [ ! -d .git ]; then
  echo "FAIL: $REPO is not a Git repository (no .git/)."
  exit 1
fi

# HEAD on main?
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ]; then
  echo "  OK   HEAD on branch: main"
else
  echo "  FAIL HEAD on branch: '$branch' (expected main)"
  fail=$((fail+1))
fi

# Count commits
count="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
if [ "$count" -ge 5 ]; then
  echo "  OK   commits on main: $count (>=5)"
else
  echo "  FAIL commits on main: $count (expected >=5)"
  fail=$((fail+1))
fi

# Author configured
author="$(git log --format='%an <%ae>' -n1 2>/dev/null || true)"
if [ -n "$author" ] && [[ "$author" =~ \<.+@.+\..+\> ]]; then
  echo "  OK   author: $author"
else
  echo "  FAIL author missing or malformed: '$author'"
  fail=$((fail+1))
fi

# Tree of HEAD contains README.md, src/, tests/
entries="$(git ls-tree -r --name-only HEAD 2>/dev/null | sort | uniq)"
for want in "README.md" "src/hello.py" "tests/test_hello.py"; do
  if echo "$entries" | grep -qx "$want"; then
    echo "  OK   tree contains: $want"
  else
    echo "  FAIL tree missing: $want"
    fail=$((fail+1))
  fi
done

# fsck clean (allow dangling but no errors)
if git fsck --no-progress 2>&1 | grep -qiE 'error|missing|corrupt'; then
  echo "  FAIL git fsck reported errors."
  fail=$((fail+1))
else
  echo "  OK   git fsck clean"
fi

# Refs file exists
if [ -f .git/refs/heads/main ] || git show-ref --verify --quiet refs/heads/main; then
  echo "  OK   refs/heads/main is a valid ref"
else
  echo "  FAIL refs/heads/main not found"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
