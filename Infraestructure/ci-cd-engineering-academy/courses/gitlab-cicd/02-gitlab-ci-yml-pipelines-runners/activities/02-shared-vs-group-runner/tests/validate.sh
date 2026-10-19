#!/usr/bin/env bash
# Structural validation for gl-02-02-shared-vs-group-runner.
# Checks ADR-RUNNERS.md has the ADR sections and the required content:
#   - mentions shared and group runners
#   - mentions gitlab.com / SaaS
#   - mentions tags:
#   - mentions both workloads (checkout, analytics)
#   - lists >=3 decision criteria tokens
#   - lists >=2 alternatives
#   - includes at least one fenced code block (the tags: YAML sample)
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantics — compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-02-02}"
DOC="$BASE/ADR-RUNNERS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-RUNNERS.md has an 'ADR' heading"
else
  echo "  FAIL ADR-RUNNERS.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   has '${label}' section"
  else
    echo "  FAIL missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Fenced code block (tags: YAML sample).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, YAML block needs opening+closing)"
  fail=$((fail+1))
fi

# Shared and group runner mentions.
if grep -qiE '\bshared\b' "$DOC"; then
  echo "  OK   mentions 'shared'"
else
  echo "  FAIL does not mention 'shared'"
  fail=$((fail+1))
fi
if grep -qiE '\bgroup\b' "$DOC"; then
  echo "  OK   mentions 'group'"
else
  echo "  FAIL does not mention 'group'"
  fail=$((fail+1))
fi

# gitlab.com / SaaS mention.
if grep -qiE 'gitlab\.com|SaaS|saas-linux' "$DOC"; then
  echo "  OK   mentions gitlab.com / SaaS"
else
  echo "  FAIL does not mention gitlab.com / SaaS"
  fail=$((fail+1))
fi

# tags mention.
if grep -qiE '\btags?\b' "$DOC"; then
  echo "  OK   mentions tags"
else
  echo "  FAIL does not mention tags"
  fail=$((fail+1))
fi

# Both workloads.
if grep -qi 'checkout' "$DOC" && grep -qi 'analytics' "$DOC"; then
  echo "  OK   mentions both workloads (checkout and analytics)"
else
  echo "  FAIL does not mention both 'checkout' and 'analytics'"
  fail=$((fail+1))
fi

# At least 3 decision criteria tokens from a canonical set.
crit=0
for c in "coste" "cost" "minutos" "red" "VPC" "secreto" "secret" "vault" \
         "autoscal" "compliance" "operaci" "FTE" "pricing"; do
  if grep -qi "$c" "$DOC"; then
    crit=$((crit+1))
  fi
done
if [ "$crit" -ge 3 ]; then
  echo "  OK   mentions at least 3 decision criteria (${crit} tokens found)"
else
  echo "  FAIL mentions only ${crit} decision criteria tokens (expected >=3)"
  fail=$((fail+1))
fi

# At least 2 alternatives listed (sub-headings or numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2 sub-headings or numbered items)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-RUNNERS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
