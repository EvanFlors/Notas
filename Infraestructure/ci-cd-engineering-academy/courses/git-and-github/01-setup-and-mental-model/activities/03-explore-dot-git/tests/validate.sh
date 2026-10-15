#!/usr/bin/env bash
# Structural validation for gh-01-03-explore-dot-git.
# Checks that the sample repo exists AND that MAP.md has the required sections.
# Does NOT grade semantic correctness — compare manually to solution/MAP-reference.md.

set -o pipefail

REPO="${1:-/tmp/explore-dot-git}"
MAP="$REPO/MAP.md"
fail=0

echo "== Structural validation for $REPO =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO is not a Git repo. Run starter/build-sample-repo.sh first."
  exit 1
fi

# Base invariants of the sample repo
cd "$REPO"
commits_main=$(git rev-list --count main 2>/dev/null || echo 0)
if [ "$commits_main" -eq 3 ]; then
  echo "  OK   main has 3 commits"
else
  echo "  FAIL main has $commits_main commits (expected 3). Rebuild via starter/."
  fail=$((fail+1))
fi

if git show-ref --quiet refs/heads/feature/x; then
  echo "  OK   branch feature/x exists"
else
  echo "  FAIL branch feature/x missing"
  fail=$((fail+1))
fi

if git show-ref --quiet refs/tags/v0.1; then
  echo "  OK   tag v0.1 exists"
else
  echo "  FAIL tag v0.1 missing"
  fail=$((fail+1))
fi

# MAP.md presence and structure
if [ ! -f "$MAP" ]; then
  echo "FAIL: $MAP does not exist. Student must produce it."
  exit 1
fi

required_sections=(
  "Mapa anotado"
  "Diagrama de los objetos"
  "Preguntas"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$MAP"; then
    echo "  OK   MAP.md contains section: '$s'"
  else
    echo "  FAIL MAP.md missing section: '$s'"
    fail=$((fail+1))
  fi
done

# Must mention a few canonical .git/ entries
for e in "HEAD" "config" "objects" "refs/heads" "refs/tags" "info/exclude"; do
  if grep -q "$e" "$MAP"; then
    echo "  OK   MAP.md mentions '$e'"
  else
    echo "  FAIL MAP.md does not mention '$e'"
    fail=$((fail+1))
  fi
done

# Must include at least one commit hash (7+ hex chars)
if grep -Eq '[0-9a-f]{7,}' "$MAP"; then
  echo "  OK   MAP.md includes at least one object hash"
else
  echo "  FAIL MAP.md does not include any object hash"
  fail=$((fail+1))
fi

# Must answer the 7 questions (we accept any numbered list 1..7)
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$MAP"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   MAP.md appears to answer at least 7 numbered questions"
else
  echo "  FAIL MAP.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/MAP-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara MAP.md con solution/MAP-reference.md para autoevaluarte."
exit 0
