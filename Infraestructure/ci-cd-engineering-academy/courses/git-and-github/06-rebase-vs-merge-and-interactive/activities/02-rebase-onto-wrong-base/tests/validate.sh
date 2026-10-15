#!/usr/bin/env bash
# Validate gh-06-02-rebase-onto-wrong-base:
#   - feature/dashboard has exactly 3 commits on top of main
#   - subjects are the expected feat(dashboard): ...
#   - none of those commits touch RELEASE_NOTES.md or VERSION
#   - main and release/1.0 did not move
#   - working tree clean
#
# No `set -o pipefail`: multiple `git log | grep -q` patterns would SIGPIPE.

REPO="${1:-${REPO_DIR:-/tmp/rebase-onto-wrong-base}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Build with starter/build-wrong-base.sh"
  exit 1
fi
cd "$REPO"

# Branches exist
for ref in main release/1.0 feature/dashboard; do
  if git show-ref --verify --quiet "refs/heads/$ref"; then
    echo "  OK   branch $ref exists"
  else
    echo "  FAIL branch $ref missing"
    fail=$((fail+1))
  fi
done

# main and release/1.0 did not move
check_ref_unmoved() {
  local snap="$1" real="$2"
  if [ -f "$snap" ]; then
    local expected actual
    expected="$(cat "$snap")"
    actual="$(git rev-parse "$real" 2>/dev/null || echo '')"
    if [ "$expected" = "$actual" ]; then
      echo "  OK   $real did not move"
    else
      echo "  FAIL $real moved: expected $expected, got $actual"
      fail=$((fail+1))
    fi
  else
    echo "  WARN snapshot $snap missing; skipping"
  fi
}
check_ref_unmoved ".git/activity-meta/main.sha"        main
check_ref_unmoved ".git/activity-meta/release-1.0.sha" release/1.0

# Working tree clean
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean:"
  git status --short
  fail=$((fail+1))
fi

# feature/dashboard should have exactly 3 commits on top of main
count="$(git rev-list --count main..feature/dashboard)"
if [ "$count" = "3" ]; then
  echo "  OK   feature/dashboard has exactly 3 commits over main"
else
  echo "  FAIL feature/dashboard has $count commits over main (expected 3)"
  fail=$((fail+1))
fi

# Subjects (chronological order expected: scaffold, add app.js, add styles)
expected=$'feat(dashboard): scaffold\nfeat(dashboard): add app.js\nfeat(dashboard): add styles'
actual="$(git log --reverse --format='%s' main..feature/dashboard)"
if [ "$expected" = "$actual" ]; then
  echo "  OK   feature commits have the expected subjects in order"
else
  echo "  FAIL feature commit subjects mismatch."
  echo "       expected:"
  printf "%s\n" "$expected" | sed 's/^/         /'
  echo "       actual:"
  printf "%s\n" "$actual" | sed 's/^/         /'
  fail=$((fail+1))
fi

# No feature commit should touch RELEASE_NOTES.md or VERSION
offenders="$(git log --name-only --pretty=format:'::%H' main..feature/dashboard \
             | awk -v RS='::' 'NR>1 { for (i=2; i<=NF; i++) if ($i == "RELEASE_NOTES.md" || $i == "VERSION") { print; next } }')"
if [ -z "$offenders" ]; then
  echo "  OK   no feature commit touches RELEASE_NOTES.md or VERSION"
else
  echo "  FAIL some feature commits touch RELEASE_NOTES.md or VERSION:"
  echo "$offenders" | sed 's/^/         /'
  fail=$((fail+1))
fi

# Final: feature/dashboard's parent chain reaches main's tip in 3 hops
third_parent="$(git rev-parse feature/dashboard~3 2>/dev/null || echo '')"
main_tip="$(git rev-parse main 2>/dev/null || echo '')"
if [ -n "$third_parent" ] && [ "$third_parent" = "$main_tip" ]; then
  echo "  OK   feature/dashboard~3 == main tip"
else
  echo "  FAIL feature/dashboard~3 ($third_parent) != main ($main_tip)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
