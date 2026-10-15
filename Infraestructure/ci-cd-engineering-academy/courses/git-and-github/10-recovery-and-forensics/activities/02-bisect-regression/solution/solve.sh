#!/usr/bin/env bash
# Reference solution for gh-10-02-bisect-regression.
# Runs `git bisect run` and writes the identified SHA to answer.txt.
set -eu
# NOTE: no pipefail. git | grep -q and git | awk 'exit' cause SIGPIPE on git.

BASE="${1:-/tmp/bisect-lab}"
cd "$BASE/repo"

# Clean any leftover bisect state.
git bisect reset >/dev/null 2>&1 || true

git bisect start HEAD HEAD~20 >/dev/null
OUT="$(git bisect run bash "$BASE/probe.sh" 2>&1)"
echo "$OUT"

FIRST_BAD="$(echo "$OUT" | grep -oE '[0-9a-f]{40} is the first bad commit' | awk '{print $1}' | head -1 || true)"
if [ -z "$FIRST_BAD" ]; then
  echo "ERROR: could not parse 'first bad commit' from bisect output" >&2
  git bisect reset >/dev/null 2>&1 || true
  exit 1
fi

echo "$FIRST_BAD" > "$BASE/answer.txt"
echo "---"
echo "First bad commit: $FIRST_BAD"
echo "Subject:          $(git show -s --format='%s' "$FIRST_BAD")"
echo "Written to:       $BASE/answer.txt"

git bisect reset >/dev/null 2>&1 || true
