#!/usr/bin/env bash
# Validate gh-10-02-bisect-regression.
# Accepts the student's answer in two forms:
#   A) /tmp/bisect-lab/answer.txt contains the SHA of the culprit commit
#   B) An active bisect state in the repo whose current `refs/bisect/bad`
#      matches the expected commit (via subject lookup).
#
# No pipefail: pipes with grep -q / awk exit early cause SIGPIPE on git.

BASE="${1:-${BASE_DIR:-/tmp/bisect-lab}}"
REPO="$BASE/repo"

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: repo missing under $REPO. Run starter/build-regression-repo.sh first."
  exit 1
fi

cd "$REPO"

# Resolve the SHA of the planted regression by its exact subject.
EXPECTED="$(git log --all --format='%H %s' | awk '{sha=$1; sub(/^[^ ]+ /,""); if ($0=="refactor: swap operator (regression)") {print sha; exit}}')"

if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not locate expected 'refactor: swap operator (regression)' commit in repo."
  exit 1
fi

answer_sha=""

# Form A: answer.txt
if [ -f "$BASE/answer.txt" ]; then
  raw="$(tr -d '[:space:]' < "$BASE/answer.txt")"
  if [ -n "$raw" ]; then
    # Expand short SHA to full if needed.
    full="$(git rev-parse --verify --quiet "$raw" || true)"
    if [ -n "$full" ]; then
      answer_sha="$full"
    fi
  fi
fi

# Form B: active bisect state — refs/bisect/bad
if [ -z "$answer_sha" ] && [ -f "$REPO/.git/refs/bisect/bad" ]; then
  bad_sha="$(cat "$REPO/.git/refs/bisect/bad" | tr -d '[:space:]')"
  if [ -n "$bad_sha" ]; then
    answer_sha="$bad_sha"
  fi
fi

# Form B2: BISECT_LOG mentions "first bad commit is <sha>"
if [ -z "$answer_sha" ] && [ -f "$REPO/.git/BISECT_LOG" ]; then
  from_log="$(grep -oE '[0-9a-f]{40}' "$REPO/.git/BISECT_LOG" | tail -1 || true)"
  if [ -n "$from_log" ]; then
    answer_sha="$from_log"
  fi
fi

if [ -z "$answer_sha" ]; then
  echo "FAIL: no answer found."
  echo "       Expected either '$BASE/answer.txt' with the SHA, or an active"
  echo "       bisect state in $REPO (.git/refs/bisect/bad or BISECT_LOG)."
  exit 1
fi

if [ "$answer_sha" = "$EXPECTED" ]; then
  echo "OK: identified culprit $answer_sha"
  echo "    subject: $(git show -s --format='%s' "$EXPECTED")"
  echo "RESULT: OK"
  exit 0
fi

echo "FAIL: expected $EXPECTED"
echo "       got      $answer_sha"
echo "       subject(expected): $(git show -s --format='%s' "$EXPECTED")"
echo "       subject(got):      $(git show -s --format='%s' "$answer_sha" 2>/dev/null || echo '<unknown>')"
exit 1
