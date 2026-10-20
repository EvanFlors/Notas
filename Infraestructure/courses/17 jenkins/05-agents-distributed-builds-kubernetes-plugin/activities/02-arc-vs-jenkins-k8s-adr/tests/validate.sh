#!/usr/bin/env bash
# Structural validation for jk-05-02-arc-vs-jenkins-k8s-adr.
# Checks that ADR-ARC-VS-K8S-PLUGIN.md exists and contains the required
# ADR sections, mentions both options (Jenkins + Kubernetes plugin, ARC +
# GitHub Actions), at least 3 comparison dimensions, Shared Libraries and
# ephemeral Pods, plus at least 2 discarded alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-05-arc-adr}"
DOC="$BASE/ADR-ARC-VS-K8S-PLUGIN.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-ARC-VS-K8S-PLUGIN.md has an 'ADR' heading"
else
  echo "  FAIL ADR-ARC-VS-K8S-PLUGIN.md missing an 'ADR' heading"
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

# Must mention both options.
if grep -qiE 'Jenkins' "$DOC" && grep -qiE 'Kubernetes +plugin|k8s +plugin' "$DOC"; then
  echo "  OK   mentions Jenkins + Kubernetes plugin"
else
  echo "  FAIL does not mention Jenkins AND Kubernetes plugin"
  fail=$((fail+1))
fi

if grep -qiE '\bARC\b|Actions +Runner +Controller' "$DOC" \
   && grep -qiE 'GitHub +Actions|GitHub +Enterprise' "$DOC"; then
  echo "  OK   mentions ARC + GitHub Actions"
else
  echo "  FAIL does not mention ARC AND GitHub Actions"
  fail=$((fail+1))
fi

# Must mention at least 3 comparison dimensions out of a canonical set.
dims=0
for d in "control +plane" "network" "escal" "goberna" "inercia" "coste" "costo" \
         "observabilid" "security|seguridad"; do
  if grep -qiE "$d" "$DOC"; then
    dims=$((dims+1))
  fi
done
if [ "$dims" -ge 3 ]; then
  echo "  OK   mentions at least 3 comparison dimensions (${dims} tokens found)"
else
  echo "  FAIL mentions only ${dims} comparison dimensions (expected >=3)"
  fail=$((fail+1))
fi

# Must mention Shared Libraries.
if grep -qiE 'Shared +Librar(y|ies)|shared-librar' "$DOC"; then
  echo "  OK   mentions Shared Libraries"
else
  echo "  FAIL does not mention Shared Libraries"
  fail=$((fail+1))
fi

# Must mention ephemeral Pods.
if grep -qiE 'ef[ií]mer|ephemeral' "$DOC" && grep -qiE 'Pod' "$DOC"; then
  echo "  OK   mentions ephemeral Pods"
else
  echo "  FAIL does not mention ephemeral Pods"
  fail=$((fail+1))
fi

# Alternatives: at least 2 listed as sub-headings or numbered items.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-ARC-VS-K8S-PLUGIN.md con solution/REFERENCE.md."
exit 0
