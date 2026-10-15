#!/usr/bin/env bash
# Validator for gh-09-01-commit-from-scratch-plumbing.
#
# Note: deliberately NO `set -o pipefail` because several checks use
# `... | grep -q ...` which produces SIGPIPE (exit 141) in the upstream command
# when grep matches early; pipefail would spuriously mark those as failures.

BASE="${1:-${BASE_DIR:-/tmp/plumbing-lab}}"
passed=0
failed=0
report=""

fail() { report+="FAIL: $1\n"; failed=$((failed+1)); }
pass() { report+="OK:   $1\n"; passed=$((passed+1)); }

if [ ! -d "$BASE/.git" ]; then
  echo "FAIL: $BASE is not a git repo. Run starter/setup-lab.sh first."
  exit 1
fi

cd "$BASE"

# 1) main exists
if ! git show-ref --verify --quiet refs/heads/main; then
  fail "refs/heads/main does not exist"
  echo
  printf "%b" "$report"
  exit 1
fi
pass "refs/heads/main exists"

HEAD_HASH=$(git rev-parse HEAD)
HEAD_SUBJECT=$(git log -n1 --format='%s' HEAD)

# 2) HEAD subject = "feat: add greeter"
if [ "$HEAD_SUBJECT" = "feat: add greeter" ]; then
  pass "HEAD subject is 'feat: add greeter'"
else
  fail "HEAD subject is '$HEAD_SUBJECT' (expected 'feat: add greeter')"
fi

# 3) HEAD has exactly one parent
PARENT_COUNT=$(git cat-file -p HEAD | grep -c '^parent ' || true)
if [ "$PARENT_COUNT" -eq 1 ]; then
  pass "HEAD has exactly one parent"
else
  fail "HEAD has $PARENT_COUNT parents (expected 1)"
fi

# 4) Parent subject = "init: hello"
PARENT_HASH=$(git rev-parse HEAD^ 2>/dev/null || echo "")
if [ -z "$PARENT_HASH" ]; then
  fail "cannot resolve HEAD^"
else
  PARENT_SUBJECT=$(git log -n1 --format='%s' "$PARENT_HASH")
  if [ "$PARENT_SUBJECT" = "init: hello" ]; then
    pass "Parent subject is 'init: hello'"
  else
    fail "Parent subject is '$PARENT_SUBJECT' (expected 'init: hello')"
  fi
fi

# 5) Parent has NO parent (is a root commit)
if [ -n "$PARENT_HASH" ]; then
  ROOT_PARENT_COUNT=$(git cat-file -p "$PARENT_HASH" | grep -c '^parent ' || true)
  if [ "$ROOT_PARENT_COUNT" -eq 0 ]; then
    pass "Initial commit has no parent (is a root)"
  else
    fail "Initial commit has $ROOT_PARENT_COUNT parents (expected 0)"
  fi
fi

# Expected blob hashes (deterministic by content)
EXPECTED_HELLO_BLOB="ce013625030ba8dba906f756967f9e9ca394464a"
EXPECTED_GREETER_BLOB="21ba682558a42264518f1e0ba55e8a5cd9d7db0a"

# 6) HEAD tree contains exactly hello.txt + greeter.sh with correct modes & hashes
HEAD_TREE_RAW=$(git ls-tree HEAD | sort)
EXPECTED_HEAD_TREE=$(printf '100644 blob %s\tgreeter.sh\n100644 blob %s\thello.txt\n' \
  "$EXPECTED_GREETER_BLOB" "$EXPECTED_HELLO_BLOB" | sort)
# Note: greeter.sh may be 100755 (expected) OR 100644 (if student forgot the mode).
# We check with 100755 first, then fall back and report missing mode.

# Build the correct expected (with 100755 for greeter.sh)
EXPECTED_HEAD_TREE=$(printf '100755 blob %s\tgreeter.sh\n100644 blob %s\thello.txt\n' \
  "$EXPECTED_GREETER_BLOB" "$EXPECTED_HELLO_BLOB" | sort)

if [ "$HEAD_TREE_RAW" = "$EXPECTED_HEAD_TREE" ]; then
  pass "HEAD tree is exactly {hello.txt 100644, greeter.sh 100755} with correct hashes"
else
  fail "HEAD tree mismatch. Got:"
  report+="----\n$HEAD_TREE_RAW\n----\nExpected:\n----\n$EXPECTED_HEAD_TREE\n----\n"
fi

# 7) Parent tree contains ONLY hello.txt with the same blob
if [ -n "$PARENT_HASH" ]; then
  PARENT_TREE_RAW=$(git ls-tree "$PARENT_HASH" | sort)
  EXPECTED_PARENT_TREE=$(printf '100644 blob %s\thello.txt\n' "$EXPECTED_HELLO_BLOB")
  if [ "$PARENT_TREE_RAW" = "$EXPECTED_PARENT_TREE" ]; then
    pass "Parent tree is exactly {hello.txt 100644} with correct hash"
  else
    fail "Parent tree mismatch. Got:"
    report+="----\n$PARENT_TREE_RAW\n----\nExpected:\n----\n$EXPECTED_PARENT_TREE\n----\n"
  fi
fi

# 8) Blob contents match exactly
HELLO_CONTENT=$(git cat-file -p "$EXPECTED_HELLO_BLOB" 2>/dev/null || echo "<missing>")
if [ "$HELLO_CONTENT" = "hello" ]; then
  # git cat-file -p prints the raw content; a trailing \n is included but shell strips.
  # The blob we hashed was "hello\n" (6 bytes), size check:
  SZ=$(git cat-file -s "$EXPECTED_HELLO_BLOB" 2>/dev/null || echo 0)
  if [ "$SZ" -eq 6 ]; then
    pass "Blob hello.txt is exactly 'hello\\n' (6 bytes)"
  else
    fail "Blob hello.txt size is $SZ (expected 6)"
  fi
else
  fail "Blob hello.txt content is '$HELLO_CONTENT' (expected 'hello')"
fi

GREETER_SIZE=$(git cat-file -s "$EXPECTED_GREETER_BLOB" 2>/dev/null || echo 0)
# "#!/bin/sh\necho hello\n" = 21 bytes
if [ "$GREETER_SIZE" -eq 21 ]; then
  pass "Blob greeter.sh is 21 bytes (matches '#!/bin/sh\\necho hello\\n')"
else
  fail "Blob greeter.sh size is $GREETER_SIZE (expected 21)"
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
