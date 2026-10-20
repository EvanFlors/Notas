#!/usr/bin/env bash
# Structural validation for gcp-05-01-connect-fastapi-to-cloud-sql.
# Checks main.py (FastAPI + endpoints + DATABASE_URL), requirements.txt,
# main.tf (Cloud SQL + Auth Proxy pattern + SA + IAM auth), and
# ADR-DB-CHOICE.md (5 ADR sections + required mentions + alternatives).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT apply Terraform, does NOT run the app. Compare manually with
# solution/ for semantic correctness.

set -eu

BASE="${1:-/tmp/gcp-05-01}"
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

# --- main.py --------------------------------------------------------------
APP="$BASE/main.py"
if check_file_exists "$APP"; then
  check_grep "$APP" 'from fastapi import|import fastapi' 'imports FastAPI'
  check_grep "$APP" 'app[[:space:]]*=[[:space:]]*FastAPI' 'instantiates app = FastAPI(...)'
  check_grep "$APP" 'DATABASE_URL' 'reads DATABASE_URL from env'
  check_grep "$APP" '@app\.get\(["'"'"']/healthz' 'declares GET /healthz'
  check_grep "$APP" '@app\.(get|post)\(["'"'"']/items' 'declares /items endpoint'
  check_grep "$APP" 'SELECT +1|select +1' '/healthz issues SELECT 1 (db ping)'
  check_grep "$APP" 'INSERT +INTO +items|insert +into +items' 'inserts into items table'
fi

# --- requirements.txt ----------------------------------------------------
REQ="$BASE/requirements.txt"
if check_file_exists "$REQ"; then
  check_grep "$REQ" '^fastapi' 'requires fastapi'
  check_grep "$REQ" '^uvicorn' 'requires uvicorn'
  check_grep "$REQ" '^(psycopg|asyncpg)' 'requires a postgres client (psycopg or asyncpg)'
fi

# --- main.tf -------------------------------------------------------------
TF="$BASE/main.tf"
if check_file_exists "$TF"; then
  check_grep "$TF" 'required_providers' 'declares required_providers'
  check_grep "$TF" 'source[[:space:]]*=[[:space:]]*"hashicorp/google"' 'uses hashicorp/google provider'
  check_grep "$TF" 'project[[:space:]]*=[[:space:]]*"example-project-id"' 'uses example-project-id placeholder (not a real project)'
  check_grep "$TF" 'region[[:space:]]*=[[:space:]]*"europe-' 'provider region is europe-*'

  check_grep "$TF" 'resource +"google_service_account"' 'declares google_service_account'
  check_grep "$TF" 'resource +"google_project_iam_member"' 'declares google_project_iam_member'
  check_grep "$TF" 'role[[:space:]]*=[[:space:]]*"roles/cloudsql.client"' 'binds roles/cloudsql.client (Auth Proxy pattern)'

  check_grep "$TF" 'resource +"google_sql_database_instance"' 'declares google_sql_database_instance'
  check_grep "$TF" 'database_version[[:space:]]*=[[:space:]]*"POSTGRES_1[456]"' 'database_version is POSTGRES_14/15/16'
  check_grep "$TF" 'region[[:space:]]*=[[:space:]]*"europe-' 'Cloud SQL instance in europe-* region'
  check_grep "$TF" 'deletion_protection[[:space:]]*=[[:space:]]*true' 'deletion_protection = true'
  check_grep "$TF" 'ipv4_enabled[[:space:]]*=[[:space:]]*false' 'ipv4_enabled = false (Auth Proxy only, no public IP)'
  check_grep "$TF" 'point_in_time_recovery_enabled[[:space:]]*=[[:space:]]*true' 'PITR enabled'
  check_grep "$TF" 'cloudsql\.iam_authentication' 'enables cloudsql.iam_authentication'

  check_grep "$TF" 'resource +"google_sql_database"' 'declares google_sql_database'
  check_grep "$TF" 'resource +"google_sql_user"' 'declares google_sql_user'
  check_grep "$TF" 'type[[:space:]]*=[[:space:]]*"CLOUD_IAM_SERVICE_ACCOUNT"' 'google_sql_user is CLOUD_IAM_SERVICE_ACCOUNT'

  if grep -qE '"my-real-|"prod-[a-z0-9]+-[0-9]{6,}"' "$TF"; then
    echo "  FAIL $TF looks like it contains a real project id (should use example-project-id)"
    fail=$((fail+1))
  else
    echo "  OK   $TF has no obvious real project ids"
  fi
fi

# --- ADR-DB-CHOICE.md -----------------------------------------------------
DOC="$BASE/ADR-DB-CHOICE.md"
if check_file_exists "$DOC"; then
  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
      echo "  OK   ADR-DB-CHOICE.md has '${label}' section"
    else
      echo "  FAIL ADR-DB-CHOICE.md missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  if grep -qiE 'Cloud +SQL' "$DOC"; then
    echo "  OK   ADR mentions Cloud SQL"
  else
    echo "  FAIL ADR does not mention Cloud SQL"
    fail=$((fail+1))
  fi

  if grep -qiE 'AlloyDB' "$DOC"; then
    echo "  OK   ADR mentions AlloyDB"
  else
    echo "  FAIL ADR does not mention AlloyDB"
    fail=$((fail+1))
  fi

  if grep -qiE 'Auth +Proxy|cloud-sql-proxy|cloudsql[-_]proxy' "$DOC"; then
    echo "  OK   ADR mentions Auth Proxy / cloud-sql-proxy"
  else
    echo "  FAIL ADR does not mention Auth Proxy / cloud-sql-proxy"
    fail=$((fail+1))
  fi

  if grep -qiE 'europ|eu-west|europe-' "$DOC"; then
    echo "  OK   ADR mentions Europe / europe-* region"
  else
    echo "  FAIL ADR does not mention Europe / europe-* region"
    fail=$((fail+1))
  fi

  # Compare at least 3 criteria tokens
  crit_hits=$(grep -ciE 'coste|cost|rendimiento|performance|operaci|lock-?in|HA|high.?availability|PITR|backup' "$DOC" || true)
  if [ "$crit_hits" -ge 3 ]; then
    echo "  OK   ADR compares at least 3 criteria (${crit_hits} tokens)"
  else
    echo "  FAIL ADR compares only ${crit_hits} criteria tokens (expected >=3)"
    fail=$((fail+1))
  fi

  # At least 2 alternatives listed (numbered items or subheadings).
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
  alt_sub=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
  if [ "$alt_num" -ge 2 ] || [ "$alt_sub" -ge 2 ]; then
    echo "  OK   ADR lists at least 2 alternatives"
  else
    echo "  FAIL ADR lists fewer than 2 alternatives (expected >=2)"
    fail=$((fail+1))
  fi
fi

# --- Optional terraform validate soft check -------------------------------
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
