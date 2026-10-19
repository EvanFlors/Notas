#!/usr/bin/env bash
# Structural validation for gl-10-02-platform-adr-final.
# Checks that PLATFORM-ADR.md exists and contains the required ADR
# sections plus the mandatory content pillars (catalog, runners/cost,
# observability, Argo CD, GHA vs GitLab, Compliance).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-10-platform}"
DOC="$BASE/PLATFORM-ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi
echo "  OK   PLATFORM-ADR.md exists"

# ADR heading
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   PLATFORM-ADR.md has an 'ADR' heading"
else
  echo "  FAIL PLATFORM-ADR.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required sections
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   PLATFORM-ADR.md has '${label}' section"
  else
    echo "  FAIL PLATFORM-ADR.md missing '${label}' section"
    fail=$((fail+1))
  fi
done

# At least one fenced code block
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  fail=$((fail+1))
fi

# --- Pillar: Catalog / inner-source --------------------------------------
cat_hits=0
for token in "cat[aá]logo" "catalog" "component" "inner.source" \
             "Code Owners" "SemVer" "deprecat"; do
  if grep -qiE "$token" "$DOC"; then
    cat_hits=$((cat_hits+1))
  fi
done
if [ "$cat_hits" -ge 4 ]; then
  echo "  OK   catalog/inner-source pillar covered (${cat_hits} tokens found)"
else
  echo "  FAIL catalog/inner-source pillar covered only ${cat_hits} tokens (expected >=4)"
  fail=$((fail+1))
fi

# --- Pillar: Runners / cost ---------------------------------------------
run_hits=0
for token in "SaaS" "Fleeting" "runner" "kubernetes" "k8s" "coste" "cost"; do
  if grep -qiE "$token" "$DOC"; then
    run_hits=$((run_hits+1))
  fi
done
if [ "$run_hits" -ge 4 ]; then
  echo "  OK   runners/cost pillar covered (${run_hits} tokens found)"
else
  echo "  FAIL runners/cost pillar covered only ${run_hits} tokens (expected >=4)"
  fail=$((fail+1))
fi

# --- Pillar: Observability (>=4 metric tokens) --------------------------
obs_hits=0
for token in "duration" "success rate" "queue" "minuto" "minutes" \
             "Prometheus" "Grafana" "PromQL" "p95"; do
  if grep -qiE "$token" "$DOC"; then
    obs_hits=$((obs_hits+1))
  fi
done
if [ "$obs_hits" -ge 5 ]; then
  echo "  OK   observability pillar covered (${obs_hits} tokens found)"
else
  echo "  FAIL observability pillar covered only ${obs_hits} tokens (expected >=5)"
  fail=$((fail+1))
fi

# --- Pillar: Argo CD / GitOps -------------------------------------------
if grep -qiE 'Argo *CD|GitOps' "$DOC"; then
  echo "  OK   Argo CD / GitOps frontier mentioned"
else
  echo "  FAIL Argo CD / GitOps frontier not mentioned"
  fail=$((fail+1))
fi

# --- Pillar: Compliance Framework ---------------------------------------
if grep -qiE 'Compliance( +Framework)?' "$DOC"; then
  echo "  OK   Compliance Framework mentioned"
else
  echo "  FAIL Compliance Framework not mentioned"
  fail=$((fail+1))
fi

# --- Pillar: GHA vs GitLab for 3 orgs -----------------------------------
# Require mention of GHA/GitHub Actions AND of 3 org-size markers.
if grep -qiE 'GHA|GitHub +Actions' "$DOC"; then
  echo "  OK   mentions GHA / GitHub Actions"
else
  echo "  FAIL does not mention GHA / GitHub Actions"
  fail=$((fail+1))
fi

org_hits=0
for token in "startup" "scaleup" "enterprise" "SMB" "scale-up"; do
  if grep -qiE "$token" "$DOC"; then
    org_hits=$((org_hits+1))
  fi
done
if [ "$org_hits" -ge 3 ]; then
  echo "  OK   covers at least 3 org sizes (${org_hits} tokens found)"
else
  echo "  FAIL covers only ${org_hits} org-size tokens (expected >=3)"
  fail=$((fail+1))
fi

# --- Alternatives: >=2 ---------------------------------------------------
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
