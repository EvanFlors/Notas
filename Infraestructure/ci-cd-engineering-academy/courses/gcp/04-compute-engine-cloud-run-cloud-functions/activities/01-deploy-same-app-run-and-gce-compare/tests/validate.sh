#!/usr/bin/env bash
# Structural validation for gcp-04-01-deploy-same-app-run-and-gce-compare.
# Checks Dockerfile builds offline-shape, cloud-run.tf declares a
# google_cloud_run_v2_service with dedicated SA + port 8080, gce.tf declares
# instance template + MIG, and DECISION.md has the required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT apply anything to GCP; does NOT grade semantic correctness in a
# real project. Compare manually with solution/.

set -eu

BASE="${1:-/tmp/gcp-04-run-vs-gce}"
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

# --- Dockerfile ------------------------------------------------------------
DOCKER="$BASE/Dockerfile"
if check_file_exists "$DOCKER"; then
  check_grep "$DOCKER" '^FROM +python:' 'FROM python base image'
  check_grep "$DOCKER" '^(USER +[0-9]+|USER +[a-z]+)' 'drops privileges with USER'
  check_grep "$DOCKER" '\$\{?PORT' 'honors $PORT at runtime'
fi

check_file_exists "$BASE/main.py" || true
check_file_exists "$BASE/requirements.txt" || true

# --- cloud-run.tf ---------------------------------------------------------
CR="$BASE/cloud-run.tf"
if check_file_exists "$CR"; then
  check_grep "$CR" 'resource +"google_cloud_run_v2_service"' 'declares google_cloud_run_v2_service'
  check_grep "$CR" 'location[[:space:]]*=[[:space:]]*"europe-' 'service in a europe-* region'
  check_grep "$CR" 'service_account[[:space:]]*=' 'template.service_account is set (not default)'
  check_grep "$CR" 'container_port[[:space:]]*=[[:space:]]*8080' 'container listens on port 8080'
  check_grep "$CR" 'name[[:space:]]*=[[:space:]]*"PORT"' 'env sets PORT (so container reads $PORT)'
  check_grep "$CR" 'percent[[:space:]]*=[[:space:]]*100' 'traffic percent = 100'

  if grep -qE '//[[:space:]]*TODO [1-9]' "$CR"; then
    echo "  FAIL $CR still contains TODO markers"
    fail=$((fail+1))
  else
    echo "  OK   $CR has no remaining TODO markers"
  fi
fi

# --- gce.tf ---------------------------------------------------------------
GCE="$BASE/gce.tf"
if check_file_exists "$GCE"; then
  check_grep "$GCE" 'resource +"google_compute_instance_template"' 'declares google_compute_instance_template'
  check_grep "$GCE" 'resource +"google_compute_region_instance_group_manager"' 'declares google_compute_region_instance_group_manager'
  check_grep "$GCE" 'region[[:space:]]*=[[:space:]]*"europe-' 'MIG in a europe-* region'
  check_grep "$GCE" 'base_instance_name[[:space:]]*=' 'MIG sets base_instance_name'
  check_grep "$GCE" 'target_size[[:space:]]*=' 'MIG sets target_size'
  check_grep "$GCE" 'service_account[[:space:]]*\{' 'instance_template has service_account block'

  if grep -qE '//[[:space:]]*TODO [1-9]' "$GCE"; then
    echo "  FAIL $GCE still contains TODO markers"
    fail=$((fail+1))
  else
    echo "  OK   $GCE has no remaining TODO markers"
  fi
fi

# --- DECISION.md ----------------------------------------------------------
DOC="$BASE/DECISION.md"
if check_file_exists "$DOC"; then
  if grep -qiE '^#+ *Decisi[oó]n|^#+ *Decision' "$DOC"; then
    echo "  OK   DECISION.md has a Decision section"
  else
    echo "  FAIL DECISION.md missing a Decision section"
    fail=$((fail+1))
  fi

  if grep -qiE 'Cloud +Run' "$DOC"; then
    echo "  OK   DECISION.md mentions Cloud Run"
  else
    echo "  FAIL DECISION.md does not mention Cloud Run"
    fail=$((fail+1))
  fi

  if grep -qiE 'Compute +Engine|\\bGCE\\b' "$DOC"; then
    echo "  OK   DECISION.md mentions Compute Engine (or GCE)"
  else
    echo "  FAIL DECISION.md does not mention Compute Engine / GCE"
    fail=$((fail+1))
  fi

  # Must compare at least 3 criteria. We look for either >=3 table rows under
  # a Criterios header, or >=3 bullets, or >=3 subheadings with 'coste|cold|SO|operacion|control|rollback|deploy'.
  crit_hits=$(grep -ciE 'coste|cold *start|^#+.*SO|operaciones|control|rollback|deploy' "$DOC" || true)
  if [ "$crit_hits" -ge 3 ]; then
    echo "  OK   DECISION.md compares at least 3 criteria (${crit_hits} tokens)"
  else
    echo "  FAIL DECISION.md compares only ${crit_hits} criteria tokens (expected >=3)"
    fail=$((fail+1))
  fi

  # Must not still contain the placeholder 'TODO'.
  if grep -qE '^TODO\\b|^TODO$' "$DOC"; then
    echo "  FAIL DECISION.md still contains 'TODO' placeholders"
    fail=$((fail+1))
  else
    echo "  OK   DECISION.md has no 'TODO' placeholders"
  fi
fi

# --- Optional terraform validate soft check (opt-in via RUN_TERRAFORM=1).
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
