#!/usr/bin/env bash
# Validate structure and presence of required content in the Platform Chart
# Contract ADR. This is a mixed-validation activity: semantic correctness is
# subjective and evaluated by peer or instructor. This script only checks
# structure + required markers. We deliberately do NOT enable `set -o pipefail`
# because several checks use pipes with `grep -q` / `grep -c`, where early
# matches close the pipe and upstream `cat`/`awk` can produce SIGPIPE (141),
# which pipefail would mark as a spurious failure.

ADR_PATH="${1:-starter/ADR-001-platform-chart-contract.md}"

# Resolve relative path from the activity directory if not found cwd-relative.
if [ ! -f "$ADR_PATH" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  alt="$script_dir/../$ADR_PATH"
  if [ -f "$alt" ]; then
    ADR_PATH="$alt"
  fi
fi

fail=0

echo "== Validating Platform Chart Contract ADR at $ADR_PATH =="

if [ ! -f "$ADR_PATH" ]; then
  echo "FAIL: ADR file not found at '$ADR_PATH'"
  exit 1
fi

# Required headings (exact strings).
required_sections=(
  "# ADR-001: Platform Chart Contract"
  "## Status"
  "## Context"
  "## Decisions"
  "## Chart Contract"
  "## Versioning Policy"
  "## GitOps Integration"
  "## Boundary: Helm vs Kustomize vs Operator"
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

# Section-extraction helper.
section_of() {
  local header="$1"
  awk -v h="$header" '
    $0 == h {flag=1; next}
    /^## / && flag {flag=0}
    flag {print}
  ' "$ADR_PATH"
}

# Four explicit decisions in ## Decisions.
dec_section=$(section_of "## Decisions")

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

check_decision "library chart"    "platform-lib library chart" "no library chart"
check_decision "golden chart"     "golden chart with escape hatch" "platform-app golden chart" "one chart per app"
check_decision "GitOps engine"    "Argo CD" "ArgoCD" "Flux"
check_decision "versioning"       "SemVer with deprecation window" "SemVer" "ad-hoc" "calendar versioning"

# Chart Contract body: offers and expects, at least 6 bullets total.
cc_section=$(section_of "## Chart Contract")
offers_ok=0
expects_ok=0
if printf "%s\n" "$cc_section" | grep -Eiq 'offer|offers|provides|provide'; then offers_ok=1; fi
if printf "%s\n" "$cc_section" | grep -Eiq 'expect|expects|require|requires'; then expects_ok=1; fi
cc_bullets=$(printf "%s\n" "$cc_section" | grep -cE '^-[[:space:]]+')
if [ "$offers_ok" -eq 1 ] && [ "$expects_ok" -eq 1 ] && [ "$cc_bullets" -ge 6 ]; then
  echo "  OK   Chart Contract covers offers and expectations (bullets=$cc_bullets)"
else
  echo "  FAIL Chart Contract must describe what the chart offers AND what it expects, with >=6 total bullets (got offers=$offers_ok expects=$expects_ok bullets=$cc_bullets)"
  fail=$((fail+1))
fi

# Versioning Policy must mention MAJOR, MINOR, PATCH, deprecation and migration guide.
vp_section=$(section_of "## Versioning Policy")
vp_fail=0
for token in MAJOR MINOR PATCH; do
  if ! printf "%s\n" "$vp_section" | grep -q "$token"; then
    echo "  FAIL Versioning Policy must mention '$token'"
    vp_fail=$((vp_fail+1))
  fi
done
if ! printf "%s\n" "$vp_section" | grep -iq 'deprecation'; then
  echo "  FAIL Versioning Policy must mention 'deprecation'"
  vp_fail=$((vp_fail+1))
fi
if ! printf "%s\n" "$vp_section" | grep -Eiq 'MIGRATING\.md|migration guide'; then
  echo "  FAIL Versioning Policy must mention 'MIGRATING.md' or 'migration guide'"
  vp_fail=$((vp_fail+1))
fi
if [ "$vp_fail" -eq 0 ]; then
  echo "  OK   Versioning Policy mentions MAJOR/MINOR/PATCH + deprecation + migration guide"
else
  fail=$((fail+vp_fail))
fi

# GitOps Integration must name at least one known pitfall.
gi_section=$(section_of "## GitOps Integration")
if printf "%s\n" "$gi_section" | grep -Eiq 'hook|release name|releaseName|secret of release|helm install'; then
  echo "  OK   GitOps Integration mentions a known pitfall"
else
  echo "  FAIL GitOps Integration must name at least one known pitfall (hook / release name / Secret of release)"
  fail=$((fail+1))
fi

# Boundary section: 3 bullets AND at least one Operator decision.
b_section=$(section_of "## Boundary: Helm vs Kustomize vs Operator")
b_bullets=$(printf "%s\n" "$b_section" | grep -cE '^-[[:space:]]+')
op_mentions=$(printf "%s\n" "$b_section" | grep -c 'Operator')
if [ "$b_bullets" -ge 3 ] && [ "$op_mentions" -ge 1 ]; then
  echo "  OK   Boundary section has $b_bullets bullets and $op_mentions Operator mention(s)"
else
  echo "  FAIL Boundary section needs >=3 bullets AND >=1 'Operator' choice (got bullets=$b_bullets Operator=$op_mentions)"
  fail=$((fail+1))
fi

# Alternatives Considered: at least 3 bullets.
alt_section=$(section_of "## Alternatives Considered")
alt_bullets=$(printf "%s\n" "$alt_section" | grep -cE '^-[[:space:]]+')
if [ "$alt_bullets" -ge 3 ]; then
  echo "  OK   Alternatives Considered has $alt_bullets bullets (>=3)"
else
  echo "  FAIL Alternatives Considered needs >=3 bullets, found $alt_bullets"
  fail=$((fail+1))
fi

# Consequences: at least 4 bullets.
cons_section=$(section_of "## Consequences")
cons_bullets=$(printf "%s\n" "$cons_section" | grep -cE '^-[[:space:]]+')
if [ "$cons_bullets" -ge 4 ]; then
  echo "  OK   Consequences has $cons_bullets bullets (>=4)"
else
  echo "  FAIL Consequences needs >=4 bullets, found $cons_bullets"
  fail=$((fail+1))
fi

# Risks: at least 3 bullets AND >=3 'Mitigation' mentions.
risks_section=$(section_of "## Risks and Mitigations")
risk_bullets=$(printf "%s\n" "$risks_section" | grep -cE '^-[[:space:]]+')
mitigation_mentions=$(printf "%s\n" "$risks_section" | grep -ciE 'mitigation')
if [ "$risk_bullets" -ge 3 ] && [ "$mitigation_mentions" -ge 3 ]; then
  echo "  OK   Risks and Mitigations has $risk_bullets risks and $mitigation_mentions mitigation mentions"
else
  echo "  FAIL Risks and Mitigations needs >=3 risks AND >=3 'Mitigation' mentions (got risks=$risk_bullets mitig=$mitigation_mentions)"
  fail=$((fail+1))
fi

# Review Triggers: at least 2 bullets.
rev_section=$(section_of "## Review Triggers")
rev_bullets=$(printf "%s\n" "$rev_section" | grep -cE '^-[[:space:]]+')
if [ "$rev_bullets" -ge 2 ]; then
  echo "  OK   Review Triggers has $rev_bullets bullet(s) (>=2)"
else
  echo "  FAIL Review Triggers needs >=2 bullets, found $rev_bullets"
  fail=$((fail+1))
fi

# Word count soft check.
word_count=$(wc -w < "$ADR_PATH" | tr -d ' ')
if [ "$word_count" -ge 800 ]; then
  echo "  OK   word count: $word_count (>=800)"
else
  echo "  FAIL word count: $word_count (<800) — develop the ADR further"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: Platform Chart Contract ADR structure and content verified."
echo "   Note: semantic correctness is evaluated in peer review."
exit 0
