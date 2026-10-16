#!/usr/bin/env bash
# Structural validation for sec-03-01-pick-tooling-for-capstone.
# Checks that TOOLING.md exists and contains the required sections,
# the matrix table, the pipeline block, and the discards section.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -c ...` or `... | grep -q ...` which can produce SIGPIPE
# (exit 141) when grep finds a match early. pipefail would spuriously mark
# those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-03-tooling}"
DOC="$BASE/TOOLING.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section A — Matriz / Matrix.
if grep -qiE '^#+ *(Secci[óo]n +A|Matriz|Matrix)' "$DOC"; then
  echo "  OK   TOOLING.md has Section A (Matriz)"
else
  echo "  FAIL TOOLING.md missing Section A / Matriz heading"
  fail=$((fail+1))
fi

# Section B — Pipeline.
if grep -qiE '^#+ *(Secci[óo]n +B|Pipeline|Gates)' "$DOC"; then
  echo "  OK   TOOLING.md has Section B (Pipeline)"
else
  echo "  FAIL TOOLING.md missing Section B / Pipeline heading"
  fail=$((fail+1))
fi

# Section C — Descartes / Limitaciones.
if grep -qiE '^#+ *(Secci[óo]n +C|Descartes|Limitaciones|Fuera)' "$DOC"; then
  echo "  OK   TOOLING.md has Section C (Descartes/Limitaciones)"
else
  echo "  FAIL TOOLING.md missing Section C / Descartes heading"
  fail=$((fail+1))
fi

# Matrix table must have at least 6 rows (header + separator + 6 = 8 pipe-lines).
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 8 ]; then
  echo "  OK   TOOLING.md matrix has at least 6 rows ($rows pipe-lines found)"
else
  echo "  FAIL TOOLING.md matrix has only $rows pipe-lines (expected >=8)"
  fail=$((fail+1))
fi

# Must name at least 6 of the 7 canonical categories.
cats=0
for c in "sast" "dast" "sca" "iac" "container" "secret" "cspm"; do
  if grep -qi "$c" "$DOC"; then
    cats=$((cats+1))
  fi
done
if [ "$cats" -ge 6 ]; then
  echo "  OK   TOOLING.md names at least 6 canonical categories ($cats found)"
else
  echo "  FAIL TOOLING.md names only $cats canonical categories (expected >=6)"
  fail=$((fail+1))
fi

# Must name at least 5 canonical tools from across categories.
tools=0
for t in "semgrep" "codeql" "bandit" "trivy" "grype" "snyk" \
         "checkov" "tfsec" "terrascan" "gitleaks" "trufflehog" \
         "zap" "burp" "nuclei" "prowler" "steampipe"; do
  if grep -qi "$t" "$DOC"; then
    tools=$((tools+1))
  fi
done
if [ "$tools" -ge 5 ]; then
  echo "  OK   TOOLING.md names at least 5 canonical tools ($tools found)"
else
  echo "  FAIL TOOLING.md names only $tools canonical tools (expected >=5)"
  fail=$((fail+1))
fi

# Must mention at least 4 distinct execution points.
points=0
for p in "pre-commit" "pr " "pr\\s" "pullrequest" "pull request" "ci " "ci\\s" \
         "nightly" "registry" "admisi" "admission" "push protection" "preview"; do
  if grep -qiE "$p" "$DOC"; then
    points=$((points+1))
  fi
done
if [ "$points" -ge 4 ]; then
  echo "  OK   TOOLING.md mentions at least 4 execution points ($points found)"
else
  echo "  FAIL TOOLING.md mentions only $points execution points (expected >=4)"
  fail=$((fail+1))
fi

# Section C: must mention at least 3 discard markers.
discards=$(grep -cEi 'descart|rechaz|no se eligi|no elegi|en vez de|instead of|no primary|not primary' "$DOC" || true)
if [ "$discards" -ge 3 ]; then
  echo "  OK   TOOLING.md has at least 3 discard markers ($discards found)"
else
  echo "  FAIL TOOLING.md has $discards discard markers (expected >=3)"
  fail=$((fail+1))
fi

# Must mention 'justif' at least once (justification column).
if grep -qiE 'justif' "$DOC"; then
  echo "  OK   TOOLING.md mentions justification"
else
  echo "  FAIL TOOLING.md does not mention justification"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara TOOLING.md con solution/REFERENCE.md para autoevaluarte."
exit 0
