#!/usr/bin/env bash
# Validate gh-03-01-branch-and-merge.
# Note: deliberately NO `set -o pipefail` because many checks use
# `git log ... | grep -q ...` and SIGPIPE from git produces exit 141 spuriously
# when grep matches early. We handle exits per-check.

REPO="${1:-${REPO_DIR:-/tmp/branch-merge}}"
fail=0

echo "== Validating $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Run starter/build-starter.sh first."
  exit 1
fi
cd "$REPO"

# 1. HEAD on main
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ]; then
  echo "  OK   HEAD on main"
else
  echo "  FAIL HEAD on '$branch' (expected main)"
  fail=$((fail+1))
fi

# 2. Working tree clean
if [ -z "$(git status --porcelain)" ]; then
  echo "  OK   working tree clean"
else
  echo "  FAIL working tree not clean. git status:"
  git status --short
  fail=$((fail+1))
fi

# 3. Task 1 — Typo fix commit reachable from main, title corrected
typo_commit="$(git log main --format='%s' | grep -x 'fix: correct Notes title typo' || true)"
if [ -n "$typo_commit" ]; then
  echo "  OK   Task 1 — commit 'fix: correct Notes title typo' present on main"
else
  echo "  FAIL Task 1 — commit 'fix: correct Notes title typo' not found on main"
  fail=$((fail+1))
fi

# Also verify there is NO merge commit named for the typo fix (expected FF, not merge).
# Not strict — the activity accepts a merge commit here too — we only check title/content.

# 4. Task 2 — Usage section in notes.md and INSTALL.md file both present
has_usage=0; has_install=0
if grep -q '^## Usage$' notes.md 2>/dev/null; then has_usage=1; fi
if [ -f INSTALL.md ]; then has_install=1; fi
if [ "$has_usage" -eq 1 ] && [ "$has_install" -eq 1 ]; then
  echo "  OK   Task 2 — '## Usage' in notes.md and INSTALL.md both present"
else
  [ "$has_usage" -eq 0 ]   && { echo "  FAIL Task 2 — '## Usage' section missing from notes.md"; fail=$((fail+1)); }
  [ "$has_install" -eq 0 ] && { echo "  FAIL Task 2 — INSTALL.md file missing"; fail=$((fail+1)); }
fi

# 5. Task 2 — merge commit for feature/usage reachable from main
usage_merge="$(git log main --format='%s' | grep -x "Merge branch 'feature/usage'" || true)"
if [ -n "$usage_merge" ]; then
  echo "  OK   Task 2 — merge commit \"Merge branch 'feature/usage'\" on main"
else
  echo "  FAIL Task 2 — merge commit \"Merge branch 'feature/usage'\" not found on main"
  fail=$((fail+1))
fi

# 6. Task 3 — Resolved title line
head_line="$(head -n1 notes.md 2>/dev/null || true)"
if [ "$head_line" = "# Notes — personal project" ]; then
  echo "  OK   Task 3 — first line of notes.md is '# Notes — personal project'"
else
  echo "  FAIL Task 3 — first line of notes.md is '$head_line' (expected '# Notes — personal project')"
  fail=$((fail+1))
fi

# 7. No conflict markers anywhere in tracked files
if git grep -lE '^(<<<<<<<|=======|>>>>>>>)' -- . >/dev/null 2>&1; then
  echo "  FAIL leftover conflict markers found in tracked files:"
  git grep -lE '^(<<<<<<<|=======|>>>>>>>)' -- . | sed 's/^/     /'
  fail=$((fail+1))
else
  echo "  OK   no conflict markers in tracked files"
fi

# 8. At least one merge commit reachable from main (2+ parents)
merge_count="$(git log main --merges --format='%H' | wc -l | tr -d ' ')"
if [ "$merge_count" -ge 1 ]; then
  echo "  OK   main contains $merge_count merge commit(s)"
else
  echo "  FAIL main contains no merge commit (expected at least 1)"
  fail=$((fail+1))
fi

# 9. Branches feature/usage and feature/subtitle still exist
for b in feature/usage feature/subtitle; do
  if git show-ref --verify --quiet "refs/heads/$b"; then
    echo "  OK   branch '$b' exists"
  else
    echo "  FAIL branch '$b' does not exist"
    fail=$((fail+1))
  fi
done

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
