#!/usr/bin/env bash
# Validate gh-08-02-simulate-gitflow.
# No pipefail (grep -q on git pipelines).

REPO="${1:-${REPO_DIR:-/tmp/gitflow-sim}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a git repo. Build it first with starter/build-starter.sh"
  exit 1
fi
cd "$REPO"

# Both long-lived branches exist
for b in main develop; do
  if git show-ref --verify --quiet "refs/heads/$b"; then
    echo "  OK   branch '$b' exists"
  else
    echo "  FAIL branch '$b' missing"
    fail=$((fail+1))
  fi
done

# No stray short-lived branches
stray=$(git for-each-ref --format='%(refname:short)' refs/heads/ \
          | grep -E '^(feature|release|hotfix)/' || true)
if [ -z "$stray" ]; then
  echo "  OK   no leftover feature/*, release/*, hotfix/* branches"
else
  echo "  FAIL leftover short-lived branches: $stray"
  fail=$((fail+1))
fi

# Tags present
for t in v0.1.0 v1.0.0 v1.0.1; do
  if git rev-parse --verify --quiet "refs/tags/$t" >/dev/null; then
    echo "  OK   tag '$t' exists"
  else
    echo "  FAIL tag '$t' missing"
    fail=$((fail+1))
  fi
done

# Tags v1.0.0 and v1.0.1 must point to commits reachable from main
for t in v1.0.0 v1.0.1; do
  tag_commit=$(git rev-list -n 1 "$t" 2>/dev/null || true)
  if [ -n "$tag_commit" ] && git merge-base --is-ancestor "$tag_commit" main 2>/dev/null; then
    echo "  OK   tag '$t' reachable from main"
  else
    echo "  FAIL tag '$t' not reachable from main"
    fail=$((fail+1))
  fi
done

# Required merge commits by subject on main
for subj in \
    "merge: release/1.0.0 into main" \
    "merge: hotfix/typo into main"; do
  if git log main --format='%s' | grep -Fxq "$subj"; then
    echo "  OK   main contains merge: '$subj'"
  else
    echo "  FAIL main missing merge: '$subj'"
    fail=$((fail+1))
  fi
done

# Required merge commits by subject on develop (the double merges)
for subj in \
    "merge: feature/greet-name into develop" \
    "merge: feature/farewell into develop" \
    "merge: release/1.0.0 back into develop" \
    "merge: hotfix/typo back into develop"; do
  if git log develop --format='%s' | grep -Fxq "$subj"; then
    echo "  OK   develop contains merge: '$subj'"
  else
    echo "  FAIL develop missing merge: '$subj'"
    fail=$((fail+1))
  fi
done

# Each required merge must have 2+ parents
check_merge_commit() {
  local branch="$1" subj="$2"
  local hash
  hash=$(git log "$branch" --format='%H %s' | awk -v s="$subj" '$0 ~ "^[0-9a-f]+ "s"$"{print $1; exit}')
  if [ -z "$hash" ]; then return; fi
  local pc
  pc=$(git rev-list --parents -n 1 "$hash" | awk '{print NF-1}')
  if [ "$pc" -lt 2 ]; then
    echo "  FAIL '$subj' is NOT a real merge (parents=$pc). Use --no-ff."
    fail=$((fail+1))
  fi
}
check_merge_commit main "merge: release/1.0.0 into main"
check_merge_commit main "merge: hotfix/typo into main"
check_merge_commit develop "merge: feature/greet-name into develop"
check_merge_commit develop "merge: feature/farewell into develop"
check_merge_commit develop "merge: release/1.0.0 back into develop"
check_merge_commit develop "merge: hotfix/typo back into develop"

# Feature commits present in BOTH main and develop
for subj in "feat(greet): accept optional name" "feat(farewell): add farewell()"; do
  main_has=$(git log main --format='%s' | grep -Fxq "$subj" && echo yes || echo no)
  dev_has=$(git log develop --format='%s' | grep -Fxq "$subj" && echo yes || echo no)
  if [ "$main_has" = yes ] && [ "$dev_has" = yes ]; then
    echo "  OK   both main and develop reach '$subj'"
  else
    echo "  FAIL '$subj' reach: main=$main_has develop=$dev_has"
    fail=$((fail+1))
  fi
done

# Hotfix commit present in BOTH
subj="fix(greet): fix typo in default greeting (v1.0.1)"
main_has=$(git log main --format='%s' | grep -Fxq "$subj" && echo yes || echo no)
dev_has=$(git log develop --format='%s' | grep -Fxq "$subj" && echo yes || echo no)
if [ "$main_has" = yes ] && [ "$dev_has" = yes ]; then
  echo "  OK   both main and develop reach hotfix commit"
else
  echo "  FAIL hotfix reach: main=$main_has develop=$dev_has (did you merge back to develop?)"
  fail=$((fail+1))
fi

# Working tree clean
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
