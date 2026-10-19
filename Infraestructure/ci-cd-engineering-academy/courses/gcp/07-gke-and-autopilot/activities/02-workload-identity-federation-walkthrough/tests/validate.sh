#!/usr/bin/env bash
# Structural validation for gcp-07-02-workload-identity-federation-walkthrough.
# Checks:
#  - k8s/serviceaccount-and-deployment.yaml parses, has SA+Deployment, WIF annotation, no key-secret anti-patterns.
#  - scripts/provision-wif.sh exists, is executable, passes bash -n, contains the right commands and
#    marks itself as dry-run.
#  - WORKLOAD-IDENTITY-ADR.md has required ADR sections and content.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT execute the provision script against GCP, does NOT require a GKE
# cluster, and does NOT require real credentials.

set -eu

BASE="${1:-/tmp/gcp-07-02-wif}"
YAML="$BASE/k8s/serviceaccount-and-deployment.yaml"
SCRIPT="$BASE/scripts/provision-wif.sh"
ADR="$BASE/WORKLOAD-IDENTITY-ADR.md"
fail=0

echo "== Structural validation for $BASE =="

check_file() {
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

grep_in() {
  local f="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: $label"
  else
    echo "  FAIL $f: $label (regex: $pattern)"
    fail=$((fail+1))
  fi
}

no_grep_in() {
  local f="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  FAIL $f: $label (regex: $pattern)"
    fail=$((fail+1))
  else
    echo "  OK   $f: $label"
  fi
}

# ---- YAML -----------------------------------------------------------------
if check_file "$YAML"; then
  # YAML parse (best-effort). Prefer python3+pyyaml if available; else try kubectl --dry-run; else skip.
  if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
    if python3 -c "import yaml, sys; list(yaml.safe_load_all(open('$YAML')))" >/dev/null 2>&1; then
      echo "  OK   YAML parses (python yaml)"
    else
      echo "  FAIL YAML does not parse (python yaml)"
      fail=$((fail+1))
    fi
  elif command -v kubectl >/dev/null 2>&1; then
    if kubectl apply --dry-run=client -f "$YAML" >/dev/null 2>&1; then
      echo "  OK   YAML parses (kubectl --dry-run=client)"
    else
      echo "  FAIL YAML does not parse (kubectl --dry-run=client)"
      kubectl apply --dry-run=client -f "$YAML" 2>&1 | sed 's/^/       /'
      fail=$((fail+1))
    fi
  else
    echo "  INFO neither python3+pyyaml nor kubectl available — skipping YAML parse (content checks still enforced)"
  fi

  grep_in "$YAML" '^kind:[[:space:]]+ServiceAccount' 'contains kind: ServiceAccount'
  grep_in "$YAML" '^kind:[[:space:]]+Deployment' 'contains kind: Deployment'
  grep_in "$YAML" 'iam\.gke\.io/gcp-service-account:' 'has iam.gke.io/gcp-service-account annotation'
  grep_in "$YAML" 'iam\.gke\.io/gcp-service-account:[[:space:]]*[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.iam\.gserviceaccount\.com' 'annotation value is a GSA email'
  grep_in "$YAML" '^[[:space:]]*serviceAccountName:[[:space:]]*checkout-app' 'Deployment sets serviceAccountName: checkout-app'
  grep_in "$YAML" 'namespace:[[:space:]]*checkout' 'namespace: checkout present'

  # Negative checks: NO key-secret anti-patterns.
  # Must not DEFINE the env var (as `name: GOOGLE_...`). Mentioning it in a
  # YAML comment (e.g. "do not set GOOGLE_APPLICATION_CREDENTIALS") is fine.
  no_grep_in "$YAML" '^[[:space:]]*-?[[:space:]]*name:[[:space:]]*GOOGLE_APPLICATION_CREDENTIALS' 'does NOT define env GOOGLE_APPLICATION_CREDENTIALS'
  no_grep_in "$YAML" 'secretKeyRef.*key\.json' 'does NOT reference a key.json via secretKeyRef'
  no_grep_in "$YAML" 'secret:[[:space:]]*$' 'no secret: volume (empty check — reviewed below)'
  # Looser check for a mounted secret volume for sa keys
  if grep -qE 'secret:' "$YAML" && grep -qiE 'sa-key|service.?account.?key|gsa.?key' "$YAML"; then
    echo "  FAIL $YAML: looks like it mounts a service account key as a Secret"
    fail=$((fail+1))
  else
    echo "  OK   $YAML: no suspicious SA-key secret mount"
  fi
fi

# ---- Script ---------------------------------------------------------------
if check_file "$SCRIPT"; then
  if [ -x "$SCRIPT" ]; then
    echo "  OK   $SCRIPT is executable"
  else
    echo "  FAIL $SCRIPT is not executable (chmod +x required)"
    fail=$((fail+1))
  fi

  if bash -n "$SCRIPT" 2>/dev/null; then
    echo "  OK   $SCRIPT passes bash -n (syntax)"
  else
    echo "  FAIL $SCRIPT fails bash -n"
    bash -n "$SCRIPT" 2>&1 | sed 's/^/       /'
    fail=$((fail+1))
  fi

  grep_in "$SCRIPT" '^#!/usr/bin/env bash' 'has shebang #!/usr/bin/env bash'
  grep_in "$SCRIPT" 'set -eu' 'uses set -eu'
  # Must NOT actually enable pipefail (e.g. `set -o pipefail` or `set -euo pipefail`).
  # Mentioning the word in a comment is fine (and in fact required by the next check).
  if grep -qE '^[[:space:]]*set[[:space:]]+(-[a-z]*o[[:space:]]+pipefail|-[a-z]*uo?[[:space:]]+pipefail|-o[[:space:]]+pipefail)' "$SCRIPT"; then
    echo "  FAIL $SCRIPT: enables pipefail — remove it (SIGPIPE concern)"
    fail=$((fail+1))
  else
    echo "  OK   $SCRIPT: does NOT enable pipefail (SIGPIPE concern)"
  fi
  grep_in "$SCRIPT" 'SIGPIPE|pipefail' 'includes a note about pipefail / SIGPIPE'

  grep_in "$SCRIPT" 'workloadIdentityUser' 'mentions roles/iam.workloadIdentityUser'
  grep_in "$SCRIPT" 'svc\.id\.goog\[' 'uses the svc.id.goog[ns/ksa] principal syntax'
  grep_in "$SCRIPT" 'add-iam-policy-binding' 'uses add-iam-policy-binding'
  grep_in "$SCRIPT" 'iam\.gke\.io/gcp-service-account' 'references the K8s WIF annotation'
  grep_in "$SCRIPT" '(DRY.?RUN|do NOT execute|dry.?run)' 'marks itself as dry-run / do NOT execute'
  grep_in "$SCRIPT" 'gcloud iam service-accounts create' 'documents gcloud iam service-accounts create'
fi

# ---- ADR ------------------------------------------------------------------
if check_file "$ADR"; then
  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR has an 'ADR' heading"
  else
    echo "  FAIL ADR missing an 'ADR' heading"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # Content checks.
  grep_in "$ADR" 'IRSA' 'ADR mentions IRSA'
  grep_in "$ADR" '(Workload[[:space:]]+Identity|WIF)' 'ADR mentions Workload Identity / WIF'
  grep_in "$ADR" 'svc\.id\.goog' 'ADR mentions svc.id.goog principal'
  grep_in "$ADR" 'roles/iam\.workloadIdentityUser' 'ADR mentions roles/iam.workloadIdentityUser'
  grep_in "$ADR" '(service account key|key JSON|sa key|SA key|service-account key)' 'ADR mentions the key JSON anti-pattern'
  grep_in "$ADR" '(workload_pool|silencioso|silent)' 'ADR mentions the silent error if workload_pool missing'

  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  if [ "$alt_items" -ge 2 ]; then
    echo "  OK   ADR has at least 2 alternatives listed ($alt_items found)"
  else
    echo "  FAIL ADR has fewer than 2 alternatives (expected >=2 sub-headings)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
