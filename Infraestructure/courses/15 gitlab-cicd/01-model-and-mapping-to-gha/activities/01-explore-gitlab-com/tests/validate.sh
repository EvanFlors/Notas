#!/usr/bin/env bash
# Structural validation for gl-01-01-explore-gitlab-com.
# Checks that CHEATSHEET.md exists, has the three required sections,
# names the 10 minimum GHA<->GitLab concepts and the 10 minimum UI
# screens.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `grep -q` which can raise SIGPIPE (exit 141) when a match is found
# early. pipefail would spuriously turn those into failures.
#
# Does NOT grade semantic correctness. Compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-01-01}"
DOC="$BASE/CHEATSHEET.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like a cheatsheet (title mentioning Cheatsheet or GHA or GitLab).
if grep -qiE '^#+ *(Cheatsheet|GHA|GitLab)' "$DOC"; then
  echo "  OK   CHEATSHEET.md has a Cheatsheet/GHA/GitLab heading"
else
  echo "  FAIL CHEATSHEET.md missing a top heading mentioning Cheatsheet/GHA/GitLab"
  fail=$((fail+1))
fi

# Required sections.
for section in "Mapping" "Jerarqu[ií]a|Hierarchy|Ubicaci[oó]n|Location" "Pantallas|Screens|UI"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *.*(${section})" "$DOC"; then
    echo "  OK   has '${label}' section"
  else
    echo "  FAIL missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Must have at least one Markdown table (pipe + dashes line).
if grep -qE '^\|.*\|' "$DOC" && grep -qE '^\|[ :-]+\|' "$DOC"; then
  echo "  OK   has at least one Markdown table"
else
  echo "  FAIL does not contain a Markdown table (expected mapping/screens tables)"
  fail=$((fail+1))
fi

# --- Mapping: at least 10 of the canonical concepts must appear anywhere in the doc.
# Each concept is a group of synonyms; counting one hit per group.
mapping_hits=0
check_group() {
  # $@ is a list of patterns (case-insensitive); increments if any matches.
  for p in "$@"; do
    if grep -qiE "$p" "$DOC"; then
      mapping_hits=$((mapping_hits+1))
      return
    fi
  done
}

check_group 'workflow' 'pipeline'
check_group '\bjob\b'
check_group 'matrix'
check_group 'needs'
check_group 'secret' 'variable'
check_group 'OIDC' 'id[_ -]?token'
check_group 'pull request' '\bPR\b' 'merge request' '\bMR\b'
check_group 'organization' '\borg\b' '\bGroup\b'
check_group 'reusable workflow' 'composite' 'component' 'extends'
check_group 'environment'

if [ "$mapping_hits" -ge 10 ]; then
  echo "  OK   mapping covers ${mapping_hits}/10 required concept groups"
else
  echo "  FAIL mapping only covers ${mapping_hits}/10 required concept groups"
  fail=$((fail+1))
fi

# --- UI screens: at least 10 of the canonical UI tokens must appear.
screen_hits=0
check_screen() {
  for p in "$@"; do
    if grep -qiE "$p" "$DOC"; then
      screen_hits=$((screen_hits+1))
      return
    fi
  done
}

check_screen 'Settings'
check_screen 'CI/CD'
check_screen 'Runners'
check_screen 'Variables'
check_screen 'Protected branches' 'Protected Branches'
check_screen 'Environments'
check_screen 'Pipelines'
check_screen '\bJobs\b'
check_screen 'Catalog'
check_screen 'Repository' '\bCode\b'

if [ "$screen_hits" -ge 10 ]; then
  echo "  OK   lists ${screen_hits}/10 required UI screens"
else
  echo "  FAIL lists only ${screen_hits}/10 required UI screens"
  fail=$((fail+1))
fi

# Must mention GitLab's hierarchy keywords (at least 2 of: Instance, Group, Subgroup, Project).
hier=0
for h in "Instance" "Group" "Subgroup" "Project"; do
  if grep -qi "$h" "$DOC"; then
    hier=$((hier+1))
  fi
done
if [ "$hier" -ge 3 ]; then
  echo "  OK   mentions the hierarchy (${hier}/4 of Instance/Group/Subgroup/Project)"
else
  echo "  FAIL hierarchy coverage insufficient (${hier}/4; expected >=3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara CHEATSHEET.md con solution/REFERENCE.md para autoevaluarte."
exit 0
