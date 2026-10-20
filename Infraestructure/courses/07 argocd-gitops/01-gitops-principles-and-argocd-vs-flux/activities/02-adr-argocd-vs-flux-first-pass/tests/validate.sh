#!/usr/bin/env bash
# Structural validation for argo-01-02-adr-argocd-vs-flux-first-pass.
# Checks that ADR.md exists and contains the required sections, both tool
# names (Argo CD + Flux), at least 2 alternatives, decision concepts
# (UI / multi-cluster / image automation / PR / cultura), triggers and 7
# numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/ADR-reference.md.

BASE="${1:-/tmp/argo-01-adr}"
DOC="$BASE/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Four required ADR sections.
required_sections=(
  "Contexto"
  "Decisi"
  "Consecuencias"
  "Alternativas"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$DOC"; then
    echo "  OK   ADR.md mentions section: '$s'"
  else
    echo "  FAIL ADR.md missing section: '$s'"
    fail=$((fail+1))
  fi
done

# Must mention both tools explicitly.
if grep -qiE 'argo[- ]?cd|argocd' "$DOC"; then
  echo "  OK   mentions Argo CD"
else
  echo "  FAIL does not mention Argo CD"
  fail=$((fail+1))
fi
if grep -qi 'flux' "$DOC"; then
  echo "  OK   mentions Flux"
else
  echo "  FAIL does not mention Flux"
  fail=$((fail+1))
fi

# Must mention GitOps (defensive — avoid pure 'kubectl' doc with no gitops framing).
if grep -qi 'gitops' "$DOC"; then
  echo "  OK   mentions GitOps"
else
  echo "  FAIL does not mention GitOps"
  fail=$((fail+1))
fi

# At least one decision concept.
concepts_found=0
for kw in "ui" "multi-cluster" "multicluster" "image automation" "image updater" "image-automation" "sso" "project" "kustomization" "helmrelease" "pr"; do
  if grep -qi "$kw" "$DOC"; then
    concepts_found=$((concepts_found+1))
  fi
done
if [ "$concepts_found" -ge 2 ]; then
  echo "  OK   ADR.md mentions at least 2 decision concepts ($concepts_found found)"
else
  echo "  FAIL ADR.md mentions only $concepts_found decision concepts (expected >=2)"
  fail=$((fail+1))
fi

# At least two named alternatives beyond the two tools themselves.
alts_found=0
for alt in "jenkins" "helm upgrade" "spinnaker" "crossplane" "jenkins x" "combinaci"; do
  if grep -qi "$alt" "$DOC"; then
    alts_found=$((alts_found+1))
  fi
done
if [ "$alts_found" -ge 2 ]; then
  echo "  OK   ADR.md names at least 2 extra alternatives ($alts_found found)"
else
  echo "  FAIL ADR.md names only $alts_found extra alternatives (expected >=2)"
  fail=$((fail+1))
fi

# Must mention trigger / disparador.
if grep -qiE 'disparador|trigger' "$DOC"; then
  echo "  OK   mentions trigger/disparador for revisiting the decision"
else
  echo "  FAIL does not mention trigger/disparador"
  fail=$((fail+1))
fi

# Must mention team / equipo (team-size argument is core).
if grep -qiE 'equipo|team' "$DOC"; then
  echo "  OK   mentions team / equipo"
else
  echo "  FAIL does not mention team / equipo"
  fail=$((fail+1))
fi

# Must mention cultura/culture or philosophy/filosofia (the decision axis).
if grep -qiE 'cultur|filosof|philosoph' "$DOC"; then
  echo "  OK   mentions cultura/filosofia"
else
  echo "  FAIL does not mention cultura/filosofia"
  fail=$((fail+1))
fi

# At least 5 numbered items (triggers + answers ensure this).
numbered_lines=$(grep -cE '^[[:space:]]*[1-9]\.' "$DOC")
if [ "$numbered_lines" -ge 5 ]; then
  echo "  OK   ADR.md contains $numbered_lines numbered items"
else
  echo "  FAIL ADR.md contains only $numbered_lines numbered items (expected >=5 for triggers)"
  fail=$((fail+1))
fi

# 7 numbered answers (preguntas obligatorias) — look for 1. through 7.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$DOC"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   ADR.md answers at least 7 numbered questions"
else
  echo "  FAIL ADR.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/ADR-reference.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR.md con solution/ADR-reference.md para autoevaluarte."
exit 0
