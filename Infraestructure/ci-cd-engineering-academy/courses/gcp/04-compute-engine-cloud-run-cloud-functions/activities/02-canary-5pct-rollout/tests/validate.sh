#!/usr/bin/env bash
# Structural validation for gcp-04-02-canary-5pct-rollout.
# Checks cloud-run.tf declares a Cloud Run v2 service with two named
# revisions and a 95/5 traffic split, plus README-INTENT.md with the right
# sections and both revision names.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT apply anything to GCP. Compare manually with solution/.

set -eu

BASE="${1:-/tmp/gcp-04-canary}"
fail=0

echo "== Structural validation for $BASE =="

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_grep() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

# --- cloud-run.tf ---------------------------------------------------------
CR="$BASE/cloud-run.tf"
if check_file_exists "$CR"; then
  check_grep "$CR" 'resource +"google_cloud_run_v2_service"' 'declares google_cloud_run_v2_service'
  check_grep "$CR" 'revision[[:space:]]*=[[:space:]]*"capstone-api-v2"' 'template.revision names capstone-api-v2'
  check_grep "$CR" 'service_account[[:space:]]*=' 'template has service_account (dedicated SA)'
  check_grep "$CR" 'revision[[:space:]]*=[[:space:]]*"capstone-api-v1"' 'traffic references capstone-api-v1'
  check_grep "$CR" 'percent[[:space:]]*=[[:space:]]*95' 'traffic percent 95'
  check_grep "$CR" 'percent[[:space:]]*=[[:space:]]*5\b' 'traffic percent 5'

  # Both traffic blocks must use the REVISION allocation type.
  rev_blocks=$(grep -cE 'TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION' "$CR" || true)
  if [ "$rev_blocks" -ge 2 ]; then
    echo "  OK   two REVISION-allocation traffic blocks found (${rev_blocks})"
  else
    echo "  FAIL only ${rev_blocks} REVISION-allocation traffic blocks (expected 2)"
    fail=$((fail+1))
  fi

  if grep -qE '//[[:space:]]*TODO [1-9]' "$CR"; then
    echo "  FAIL $CR still contains TODO markers"
    fail=$((fail+1))
  else
    echo "  OK   $CR has no remaining TODO markers"
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  if grep -qi 'canary' "$DOC"; then
    echo "  OK   README-INTENT.md mentions canary"
  else
    echo "  FAIL README-INTENT.md does not mention canary"
    fail=$((fail+1))
  fi

  # Mentions both revisions by name.
  if grep -q 'capstone-api-v1' "$DOC"; then
    echo "  OK   README-INTENT.md mentions capstone-api-v1"
  else
    echo "  FAIL README-INTENT.md does not mention capstone-api-v1"
    fail=$((fail+1))
  fi
  if grep -q 'capstone-api-v2' "$DOC"; then
    echo "  OK   README-INTENT.md mentions capstone-api-v2"
  else
    echo "  FAIL README-INTENT.md does not mention capstone-api-v2"
    fail=$((fail+1))
  fi

  # Mentions the 95/5 split (either together or separate).
  if grep -qE '95[^0-9].*5\b|\\b5[^0-9].*95|95/5|95 */ *5' "$DOC"; then
    echo "  OK   README-INTENT.md mentions the 95/5 split"
  else
    echo "  FAIL README-INTENT.md does not mention 95/5"
    fail=$((fail+1))
  fi

  # Rollback procedure.
  if grep -qi 'rollback' "$DOC"; then
    echo "  OK   README-INTENT.md documents rollback"
  else
    echo "  FAIL README-INTENT.md does not document rollback"
    fail=$((fail+1))
  fi

  if grep -qE '^TODO\\b|^TODO$' "$DOC"; then
    echo "  FAIL README-INTENT.md still contains 'TODO' placeholders"
    fail=$((fail+1))
  else
    echo "  OK   README-INTENT.md has no 'TODO' placeholders"
  fi
fi

if [ "${RUN_TERRAFORM:-0}" = "1" ] && command -v terraform >/dev/null 2>&1; then
  (
    cd "$BASE"
    if terraform init -backend=false -input=false >/dev/null 2>&1 && \
       terraform validate >/dev/null 2>&1; then
      echo "  OK   terraform init && terraform validate pass locally"
    else
      echo "  WARN terraform validate did not pass (check manually)"
    fi
  )
else
  echo "  INFO 'terraform validate' soft check skipped (set RUN_TERRAFORM=1 to enable; needs network for provider download)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/ for semantic correctness.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
