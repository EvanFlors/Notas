#!/usr/bin/env bash
# Validate structure and presence of required content in the Platform Contract ADR.
# This is a mixed-validation activity: semantic correctness is subjective and
# evaluated by peer/instructor. This script only checks structure + required
# markers. We deliberately do NOT enable `set -o pipefail` because many checks
# use pipes with `grep -q` / `grep -c`, where early matches close the pipe and
# upstream `cat`/`awk` can produce SIGPIPE (141), which pipefail would mark as
# a spurious failure.

ADR_PATH="${1:-starter/ADR-001-platform-contract.md}"

# Resolve relative path from the activity directory if not found cwd-relative.
if [ ! -f "$ADR_PATH" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  alt="$script_dir/../$ADR_PATH"
  if [ -f "$alt" ]; then
    ADR_PATH="$alt"
  fi
fi

fail=0

echo "== Validating Platform Contract ADR at $ADR_PATH =="

if [ ! -f "$ADR_PATH" ]; then
  echo "FAIL: ADR file not found at '$ADR_PATH'"
  exit 1
fi

# Required headings (exact strings)
required_sections=(
  "# ADR-001: Platform Contract"
  "## Status"
  "## Context"
  "## Decisions"
  "## Platform Contract"
  "## Alternatives Considered"
  "## Consequences"
  "## Risks and Mitigations"
  "## Review Triggers"
)

for h in "${required_sections[@]}"; do
  if grep -Fxq "$h" "$ADR_PATH"; then
    echo "  OK   section present: '$h'"
  else
    echo "  FAIL section missing: '$h'"
    fail=$((fail+1))
  fi
done

# No unresolved TODO markers.
todo_count=$(grep -cE '^TODO:|^- TODO|^[[:space:]]*TODO:' "$ADR_PATH")
if [ "$todo_count" -eq 0 ]; then
  echo "  OK   no 'TODO:' markers left (starter placeholders resolved)"
else
  echo "  FAIL $todo_count 'TODO:' marker(s) still present — resolve them"
  fail=$((fail+1))
fi

# Four explicit decisions in the ## Decisions section.
dec_section=$(awk '
  /^## Decisions/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")

check_decision() {
  local label="$1"
  shift
  local found=0
  for opt in "$@"; do
    if printf "%s\n" "$dec_section" | grep -Eiq "we will adopt[^\n]*${opt}"; then
      echo "  OK   decision ($label): '$opt'"
      found=1
      break
    fi
  done
  if [ "$found" -ne 1 ]; then
    echo "  FAIL decision ($label) missing — expected 'We will adopt <one of: $*>'"
    fail=$((fail+1))
  fi
}

check_decision "packaging"        "Helm and Kustomize" "Kustomize" "Helm"
check_decision "GitOps"           "Argo CD" "ArgoCD" "Flux"
check_decision "service mesh"     "no service mesh" "Istio" "Linkerd" "Cilium Service Mesh"
check_decision "cost management"  "OpenCost" "Kubecost" "no cost management"

# Platform Contract body: two subsections or two bullet groups covering offers/expects.
pc_section=$(awk '
  /^## Platform Contract/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
offers_ok=0
expects_ok=0
if printf "%s\n" "$pc_section" | grep -Eiq 'offer|offers|provides|provide'; then offers_ok=1; fi
if printf "%s\n" "$pc_section" | grep -Eiq 'expect|expects|require|requires'; then expects_ok=1; fi
pc_bullets=$(printf "%s\n" "$pc_section" | grep -cE '^-[[:space:]]+')
if [ "$offers_ok" -eq 1 ] && [ "$expects_ok" -eq 1 ] && [ "$pc_bullets" -ge 6 ]; then
  echo "  OK   Platform Contract covers offers and expectations (bullets=$pc_bullets)"
else
  echo "  FAIL Platform Contract must describe what the platform offers AND what it expects, with >=6 total bullets (got offers=$offers_ok expects=$expects_ok bullets=$pc_bullets)"
  fail=$((fail+1))
fi

# Alternatives Considered: at least 3 bullets.
alt_section=$(awk '
  /^## Alternatives Considered/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
alt_bullets=$(printf "%s\n" "$alt_section" | grep -cE '^-[[:space:]]+')
if [ "$alt_bullets" -ge 3 ]; then
  echo "  OK   Alternatives Considered has $alt_bullets bullets (>=3)"
else
  echo "  FAIL Alternatives Considered needs >=3 bullets, found $alt_bullets"
  fail=$((fail+1))
fi

# Consequences: at least 4 bullets.
cons_section=$(awk '
  /^## Consequences/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
cons_bullets=$(printf "%s\n" "$cons_section" | grep -cE '^-[[:space:]]+')
if [ "$cons_bullets" -ge 4 ]; then
  echo "  OK   Consequences has $cons_bullets bullets (>=4)"
else
  echo "  FAIL Consequences needs >=4 bullets, found $cons_bullets"
  fail=$((fail+1))
fi

# Risks: at least 3 bullets AND at least 3 mentions of 'Mitigation'.
risks_section=$(awk '
  /^## Risks and Mitigations/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
risk_bullets=$(printf "%s\n" "$risks_section" | grep -cE '^-[[:space:]]+')
mitigation_mentions=$(printf "%s\n" "$risks_section" | grep -ciE 'mitigation')
if [ "$risk_bullets" -ge 3 ] && [ "$mitigation_mentions" -ge 3 ]; then
  echo "  OK   Risks and Mitigations has $risk_bullets risks and $mitigation_mentions mitigation mentions (>=3 each)"
else
  echo "  FAIL Risks and Mitigations needs >=3 risks AND >=3 'Mitigation' mentions (got risks=$risk_bullets mitig=$mitigation_mentions)"
  fail=$((fail+1))
fi

# Review Triggers: at least 2 bullets.
rev_section=$(awk '
  /^## Review Triggers/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
rev_bullets=$(printf "%s\n" "$rev_section" | grep -cE '^-[[:space:]]+')
if [ "$rev_bullets" -ge 2 ]; then
  echo "  OK   Review Triggers has $rev_bullets bullet(s) (>=2)"
else
  echo "  FAIL Review Triggers needs >=2 bullets, found $rev_bullets"
  fail=$((fail+1))
fi

# Word count soft check.
word_count=$(wc -w < "$ADR_PATH" | tr -d ' ')
if [ "$word_count" -ge 600 ]; then
  echo "  OK   word count: $word_count (>=600)"
else
  echo "  FAIL word count: $word_count (<600) — develop the ADR further"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: Platform Contract ADR estructura y contenido minimo verificados."
echo "   Nota: la correccion semantica/arquitectonica se evalua en revision por pares."
exit 0
