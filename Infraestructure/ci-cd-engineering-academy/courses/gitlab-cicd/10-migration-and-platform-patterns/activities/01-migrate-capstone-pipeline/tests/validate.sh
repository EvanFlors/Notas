#!/usr/bin/env bash
# Structural validation for gl-10-01-migrate-capstone-pipeline.
# Checks that MIGRATION-ADR.md and .gitlab-ci.yml exist and contain the
# minimum structural markers required by the activity.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-10-migration}"
ADR="$BASE/MIGRATION-ADR.md"
YML="$BASE/.gitlab-ci.yml"
fail=0

echo "== Structural validation for $BASE =="

# --- Files exist --------------------------------------------------------
if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR does not exist. Student must produce it."
  exit 1
fi
echo "  OK   MIGRATION-ADR.md exists"

if [ ! -f "$YML" ]; then
  echo "FAIL: $YML does not exist. Student must produce it."
  exit 1
fi
echo "  OK   .gitlab-ci.yml exists"

# --- ADR sections -------------------------------------------------------
if grep -qiE '^#+ *ADR' "$ADR"; then
  echo "  OK   MIGRATION-ADR.md has an 'ADR' heading"
else
  echo "  FAIL MIGRATION-ADR.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
    echo "  OK   MIGRATION-ADR.md has '${label}' section"
  else
    echo "  FAIL MIGRATION-ADR.md missing '${label}' section"
    fail=$((fail+1))
  fi
done

# --- ADR mandatory content ---------------------------------------------
# Mapping GHA <-> GitLab (table or list). Expect >=2 of the typical markers.
map_hits=0
for token in "workflow:" "parallel:" "matrix" "id_tokens" "CI_COMMIT_SHA" \
             "project_path" "needs:"; do
  if grep -qi "$token" "$ADR"; then
    map_hits=$((map_hits+1))
  fi
done
if [ "$map_hits" -ge 3 ]; then
  echo "  OK   MIGRATION-ADR.md shows a GHA->GitLab mapping (${map_hits} tokens found)"
else
  echo "  FAIL MIGRATION-ADR.md shows only ${map_hits} mapping tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must mention CI/CD Component or catalog
if grep -qiE 'component|cat[aá]logo|catalog' "$ADR"; then
  echo "  OK   MIGRATION-ADR.md mentions CI/CD Component / catálogo"
else
  echo "  FAIL MIGRATION-ADR.md does not mention Component / catálogo"
  fail=$((fail+1))
fi

# Must mention dual-run
if grep -qiE 'dual[- ]run|solape' "$ADR"; then
  echo "  OK   MIGRATION-ADR.md mentions dual-run"
else
  echo "  FAIL MIGRATION-ADR.md does not mention dual-run"
  fail=$((fail+1))
fi

# Must mention ID Token or OIDC
if grep -qiE 'ID[ _-]?Token|OIDC' "$ADR"; then
  echo "  OK   MIGRATION-ADR.md mentions ID Token / OIDC"
else
  echo "  FAIL MIGRATION-ADR.md does not mention ID Token / OIDC"
  fail=$((fail+1))
fi

# Trust policy claims — must pin by project_path and ref
claims_hits=0
for c in "project_path" "ref_type" "ref" "aud"; do
  if grep -q "$c" "$ADR"; then
    claims_hits=$((claims_hits+1))
  fi
done
if [ "$claims_hits" -ge 3 ]; then
  echo "  OK   MIGRATION-ADR.md pins OIDC claims (${claims_hits} of 4 found)"
else
  echo "  FAIL MIGRATION-ADR.md pins only ${claims_hits} OIDC claims (expected >=3)"
  fail=$((fail+1))
fi

# Must mention AWS
if grep -qi 'aws' "$ADR"; then
  echo "  OK   MIGRATION-ADR.md mentions AWS"
else
  echo "  FAIL MIGRATION-ADR.md does not mention AWS"
  fail=$((fail+1))
fi

# Must have at least one fenced code block (trust policy or DAG)
fences=$(grep -cE '^```' "$ADR")
if [ "$fences" -ge 2 ]; then
  echo "  OK   MIGRATION-ADR.md has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL MIGRATION-ADR.md has only ${fences} code-fence lines (expected >=2)"
  fail=$((fail+1))
fi

# Alternatives: at least 2 sub-headings or numbered items
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   MIGRATION-ADR.md lists at least 2 alternatives"
else
  echo "  FAIL MIGRATION-ADR.md lists fewer than 2 alternatives"
  fail=$((fail+1))
fi

# --- .gitlab-ci.yml top-level keys -------------------------------------
for key in "^stages:" "^workflow:" "^default:|^image:"; do
  label=$(echo "$key" | tr -d '^:')
  if grep -qE "$key" "$YML"; then
    echo "  OK   .gitlab-ci.yml has key(s) matching '${label}'"
  else
    echo "  FAIL .gitlab-ci.yml missing key(s) matching '${label}'"
    fail=$((fail+1))
  fi
done

# needs: in some job
if grep -qE '^[[:space:]]+needs:' "$YML"; then
  echo "  OK   .gitlab-ci.yml uses 'needs:' (DAG)"
else
  echo "  FAIL .gitlab-ci.yml does not use 'needs:'"
  fail=$((fail+1))
fi

# parallel: matrix:
if grep -qE '^[[:space:]]+parallel:' "$YML" && grep -qE '^[[:space:]]+matrix:' "$YML"; then
  echo "  OK   .gitlab-ci.yml uses 'parallel: matrix:'"
else
  echo "  FAIL .gitlab-ci.yml does not use 'parallel: matrix:'"
  fail=$((fail+1))
fi

# id_tokens with aud:
if grep -qE '^[[:space:]]+id_tokens:' "$YML" && grep -qE '^[[:space:]]+aud:' "$YML"; then
  echo "  OK   .gitlab-ci.yml declares 'id_tokens:' with 'aud:'"
else
  echo "  FAIL .gitlab-ci.yml missing 'id_tokens:' + 'aud:'"
  fail=$((fail+1))
fi

# rules: on main branch
if grep -qE 'CI_COMMIT_BRANCH *== *"main"' "$YML"; then
  echo "  OK   .gitlab-ci.yml filters by \$CI_COMMIT_BRANCH == \"main\""
else
  echo "  FAIL .gitlab-ci.yml does not filter by \$CI_COMMIT_BRANCH == \"main\""
  fail=$((fail+1))
fi

# At least 3 jobs — count lines that look like a top-level job definition.
# A top-level job starts at column 0 and ends with ':' (and is not a known keyword).
job_count=$(grep -cE '^[a-zA-Z][a-zA-Z0-9_.-]*:[[:space:]]*$' "$YML" || true)
# Subtract known reserved keys that match that pattern.
for reserved in "stages" "workflow" "default" "include" "variables" \
                "services" "before_script" "after_script" "image" "cache"; do
  if grep -qE "^${reserved}:[[:space:]]*$" "$YML"; then
    job_count=$((job_count-1))
  fi
done
if [ "$job_count" -ge 3 ]; then
  echo "  OK   .gitlab-ci.yml defines at least 3 jobs (${job_count} top-level jobs found)"
else
  echo "  FAIL .gitlab-ci.yml defines only ${job_count} job(s) (expected >=3)"
  fail=$((fail+1))
fi

# Mentions OIDC/AWS in comments or script
if grep -qiE 'oidc|assume-role-with-web-identity|AWS' "$YML"; then
  echo "  OK   .gitlab-ci.yml references OIDC/AWS"
else
  echo "  FAIL .gitlab-ci.yml does not reference OIDC/AWS"
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
