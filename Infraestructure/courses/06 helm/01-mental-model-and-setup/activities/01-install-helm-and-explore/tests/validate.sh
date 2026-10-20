#!/usr/bin/env bash
# Structural validation for helm-01-01-install-helm-and-explore.
# Checks that NOTES.md exists under $BASE and contains the required
# section headings, concept keywords, and at least 5 chart references.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/SOLUTION.md.

BASE="${1:-/tmp/helm-01-explore}"
NOTES="$BASE/NOTES.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$NOTES" ]; then
  echo "FAIL: $NOTES does not exist. Student must produce it."
  exit 1
fi

# Required sections (match by heading text, case-insensitive).
required_headings=(
  "helm version"
  "helm env"
  "repository"
  "artifact hub"
  "metadata"
  "values.yaml"
  "conclusi"
)
for h in "${required_headings[@]}"; do
  if grep -qi "^##.*$h" "$NOTES"; then
    echo "  OK   NOTES.md has section matching: '## ... $h ...'"
  else
    echo "  FAIL NOTES.md missing section matching: '## ... $h ...'"
    fail=$((fail+1))
  fi
done

# Core concept keywords (must appear anywhere in the file).
required_keywords=(
  "HELM_REPOSITORY_CONFIG"
  "helm search hub"
  "helm show"
  "appVersion"
  "ingress-nginx"
)
for kw in "${required_keywords[@]}"; do
  if grep -qi "$kw" "$NOTES"; then
    echo "  OK   mentions keyword '$kw'"
  else
    echo "  FAIL does not mention keyword '$kw'"
    fail=$((fail+1))
  fi
done

# Must argue values.yaml IS the chart API.
if grep -qiE "values\.yaml.*(api|interfaz|contrato|interface|contract)" "$NOTES" \
   || grep -qiE "(api|interfaz|contrato|interface|contract).*values\.yaml" "$NOTES"; then
  echo "  OK   NOTES.md argues values.yaml is the chart API/interface/contract"
else
  echo "  FAIL NOTES.md does not argue values.yaml as the API/interface/contract of the chart"
  fail=$((fail+1))
fi

# Must list at least 5 chart references (count occurrences of 'artifacthub.io'
# OR of '<repo>/<chart>' slash patterns on bullet/table lines).
hub_hits=$(grep -ci "artifacthub.io" "$NOTES" || true)
if [ "$hub_hits" -ge 5 ]; then
  echo "  OK   NOTES.md references artifacthub.io at least 5 times ($hub_hits)"
else
  echo "  FAIL NOTES.md references artifacthub.io only $hub_hits time(s) (expected >=5)"
  fail=$((fail+1))
fi

# Helm installed? If not, accept documented fallback (install instructions present).
if command -v helm >/dev/null 2>&1; then
  echo "  OK   helm binary present on this machine: $(helm version --short 2>/dev/null || echo 'version unknown')"
else
  echo "  WARN helm not installed on this machine."
  if grep -qiE "brew install helm|get-helm-3|apt install helm|choco install.*helm" "$NOTES"; then
    echo "  OK   NOTES.md documents install instructions as fallback (acceptable)."
  else
    echo "  FAIL helm absent AND NOTES.md does not document install instructions."
    echo "       Add 'brew install helm' (or the equivalent for your OS) to NOTES.md."
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/SOLUTION.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara NOTES.md con solution/SOLUTION.md para autoevaluarte."
exit 0
