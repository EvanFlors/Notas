#!/usr/bin/env bash
# Validate structure and presence of required content in the "When NOT mesh"
# analysis document. Semantic correctness is subjective and evaluated by
# peer/instructor; this script only checks structure + required markers.
#
# We deliberately do NOT enable `set -o pipefail`. Many checks use pipelines
# with `grep -q` or `grep -c`; when `grep -q` matches early it closes the pipe
# and upstream commands can exit with SIGPIPE (141), which pipefail would mark
# as a spurious failure.

DOC_PATH="${1:-starter/MESH-DECISION.md}"

# Resolve relative path from the activity directory if not found cwd-relative.
if [ ! -f "$DOC_PATH" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  alt="$script_dir/../$DOC_PATH"
  if [ -f "$alt" ]; then
    DOC_PATH="$alt"
  fi
fi

fail=0

echo "== Validating 'When NOT mesh' analysis at $DOC_PATH =="

if [ ! -f "$DOC_PATH" ]; then
  echo "FAIL: file not found at '$DOC_PATH'"
  exit 1
fi

# Required headings (exact strings).
required_sections=(
  "# Analysis: When NOT to introduce a service mesh"
  "## Scenario"
  "## Symptoms that would justify a mesh"
  "## Preconditions before introducing a mesh"
  "## Red flags against introducing a mesh"
  "## Alternatives without a mesh"
  "## Decision"
  "## Revisit Conditions"
)

for h in "${required_sections[@]}"; do
  if grep -Fxq "$h" "$DOC_PATH"; then
    echo "  OK   section present: '$h'"
  else
    echo "  FAIL section missing: '$h'"
    fail=$((fail+1))
  fi
done

# No unresolved TODO markers.
todo_count=$(grep -cE '^TODO:|^- TODO|^[[:space:]]*TODO:' "$DOC_PATH")
if [ "$todo_count" -eq 0 ]; then
  echo "  OK   no 'TODO:' markers left (starter placeholders resolved)"
else
  echo "  FAIL $todo_count 'TODO:' marker(s) still present — resolve them"
  fail=$((fail+1))
fi

# Symptoms: at least 4 bullets.
sym_section=$(awk '
  /^## Symptoms that would justify a mesh/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
sym_bullets=$(printf "%s\n" "$sym_section" | grep -cE '^-[[:space:]]+')
if [ "$sym_bullets" -ge 4 ]; then
  echo "  OK   Symptoms has $sym_bullets bullets (>=4)"
else
  echo "  FAIL Symptoms needs >=4 bullets, found $sym_bullets"
  fail=$((fail+1))
fi

# Preconditions: at least 5 bullets AND >=5 'Evidence' mentions.
pre_section=$(awk '
  /^## Preconditions before introducing a mesh/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
pre_bullets=$(printf "%s\n" "$pre_section" | grep -cE '^-[[:space:]]+')
evidence_mentions=$(printf "%s\n" "$pre_section" | grep -cE 'Evidence')
if [ "$pre_bullets" -ge 5 ] && [ "$evidence_mentions" -ge 5 ]; then
  echo "  OK   Preconditions has $pre_bullets bullets and $evidence_mentions 'Evidence' mentions (>=5 each)"
else
  echo "  FAIL Preconditions needs >=5 bullets AND >=5 'Evidence' mentions (got bullets=$pre_bullets evidence=$evidence_mentions)"
  fail=$((fail+1))
fi

# Red flags: at least 3 bullets.
rf_section=$(awk '
  /^## Red flags against introducing a mesh/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
rf_bullets=$(printf "%s\n" "$rf_section" | grep -cE '^-[[:space:]]+')
if [ "$rf_bullets" -ge 3 ]; then
  echo "  OK   Red flags has $rf_bullets bullets (>=3)"
else
  echo "  FAIL Red flags needs >=3 bullets, found $rf_bullets"
  fail=$((fail+1))
fi

# Alternatives: at least 3 bullets.
alt_section=$(awk '
  /^## Alternatives without a mesh/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
alt_bullets=$(printf "%s\n" "$alt_section" | grep -cE '^-[[:space:]]+')
if [ "$alt_bullets" -ge 3 ]; then
  echo "  OK   Alternatives has $alt_bullets bullets (>=3)"
else
  echo "  FAIL Alternatives needs >=3 bullets, found $alt_bullets"
  fail=$((fail+1))
fi

# Decision: explicit "We will NOT adopt a service mesh at this time" OR
# "We will adopt (Istio|Linkerd|Cilium Service Mesh)".
dec_section=$(awk '
  /^## Decision/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
decision_ok=0
if printf "%s\n" "$dec_section" | grep -Eiq 'we will NOT adopt a service mesh at this time'; then
  decision_ok=1
  echo "  OK   explicit decision: 'We will NOT adopt a service mesh at this time'"
fi
if [ "$decision_ok" -ne 1 ]; then
  for opt in "Istio" "Linkerd" "Cilium Service Mesh"; do
    if printf "%s\n" "$dec_section" | grep -Eiq "we will adopt[^\n]*${opt}"; then
      decision_ok=1
      echo "  OK   explicit decision: 'We will adopt $opt'"
      break
    fi
  done
fi
if [ "$decision_ok" -ne 1 ]; then
  echo "  FAIL no explicit decision found (expected 'We will NOT adopt a service mesh at this time' OR 'We will adopt <Istio|Linkerd|Cilium Service Mesh>')"
  fail=$((fail+1))
fi

# Revisit Conditions: at least 3 bullets.
rev_section=$(awk '
  /^## Revisit Conditions/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$DOC_PATH")
rev_bullets=$(printf "%s\n" "$rev_section" | grep -cE '^-[[:space:]]+')
if [ "$rev_bullets" -ge 3 ]; then
  echo "  OK   Revisit Conditions has $rev_bullets bullets (>=3)"
else
  echo "  FAIL Revisit Conditions needs >=3 bullets, found $rev_bullets"
  fail=$((fail+1))
fi

# Word count soft check.
word_count=$(wc -w < "$DOC_PATH" | tr -d ' ')
if [ "$word_count" -ge 500 ]; then
  echo "  OK   word count: $word_count (>=500)"
else
  echo "  FAIL word count: $word_count (<500) — develop the analysis further"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: analysis estructura y contenido minimo verificados."
echo "   Nota: la correccion semantica/arquitectonica se evalua en revision por pares."
exit 0
