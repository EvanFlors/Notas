#!/usr/bin/env bash
# Validate the student's refactor of a monolithic stack into
# envs/{dev,stg,prod} + modules/app.
#
# Usage: bash validate.sh [WORKDIR]
# Default WORKDIR: /tmp/tf-08-01
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which exits as soon as it finds a match and causes SIGPIPE
# (exit 141) in the upstream command. pipefail would flag those as failures.

WORK="${1:-${WORKDIR:-/tmp/tf-08-01}}"
TF_BIN="${TF_BIN:-terraform}"

passed=0
failed=0
report=""

ok()   { report+="OK   — $1\n"; passed=$((passed+1)); }
bad()  { report+="FAIL — $1 — $2\n"; failed=$((failed+1)); }

if [ ! -d "$WORK" ]; then
  echo "FAIL: workdir $WORK does not exist. Copy starter/ there first." >&2
  exit 1
fi

if ! command -v "$TF_BIN" >/dev/null 2>&1; then
  echo "FAIL: '$TF_BIN' not in PATH. Install Terraform or OpenTofu, or set TF_BIN." >&2
  exit 1
fi

echo "== Validating refactor under $WORK (using $TF_BIN) =="

# ----- Check 1: envs/{dev,stg,prod}/main.tf each call module "app"
c1_reasons=""
for env in dev stg prod; do
  f="$WORK/envs/$env/main.tf"
  if [ ! -f "$f" ]; then
    c1_reasons+=" envs/$env/main.tf missing;"
    continue
  fi
  if ! grep -q 'module[[:space:]]*"app"' "$f"; then
    c1_reasons+=" envs/$env/main.tf does not declare module \"app\";"
    continue
  fi
  if ! grep -Eq 'source[[:space:]]*=[[:space:]]*"\.\./\.\./modules/app"' "$f"; then
    c1_reasons+=" envs/$env/main.tf module source is not \"../../modules/app\";"
  fi
done
if [ -z "$c1_reasons" ]; then
  ok "envs/{dev,stg,prod}/main.tf exist and call module \"app\" via ../../modules/app"
else
  bad "env roots not well-formed" "$c1_reasons"
fi

# ----- Check 2: modules/app has the three .tf files
c2_reasons=""
mbase="$WORK/modules/app"
if [ ! -d "$mbase" ]; then
  c2_reasons+=" modules/app directory missing;"
else
  for f in main.tf variables.tf outputs.tf; do
    [ -f "$mbase/$f" ] || c2_reasons+=" modules/app/$f missing;"
  done
fi
if [ -z "$c2_reasons" ]; then
  ok "modules/app has main.tf, variables.tf, outputs.tf"
else
  bad "shared module incomplete" "$c2_reasons"
fi

# ----- Check 3: module code does NOT branch on environment name or workspace
c3_reasons=""
if [ ! -d "$mbase" ]; then
  c3_reasons+=" modules/app directory missing (cannot check);"
else
  offenders=""
  while IFS= read -r f; do
    [ -n "$f" ] && offenders+=" $(basename "$f")"
  done < <(grep -rl -E '(var\.environment[[:space:]]*==|terraform\.workspace[[:space:]]*==)' "$mbase" 2>/dev/null)
  [ -n "$offenders" ] && c3_reasons+=" branching found in:$offenders;"
fi
if [ -z "$c3_reasons" ]; then
  ok "modules/app does not branch on var.environment or terraform.workspace"
else
  bad "module branches on env name" "$c3_reasons"
fi

# ----- Check 4: each env has its own terraform.tfstate and they are distinct
c4_reasons=""
hashes=""
for env in dev stg prod; do
  s="$WORK/envs/$env/terraform.tfstate"
  if [ ! -f "$s" ]; then
    c4_reasons+=" envs/$env/terraform.tfstate missing;"
    continue
  fi
  h=$(shasum -a 256 "$s" | awk '{print $1}')
  hashes+="$h "
done
if [ -z "$c4_reasons" ]; then
  uniq=$(printf "%s\n" $hashes | sort -u | wc -l | tr -d ' ')
  if [ "$uniq" -ne 3 ]; then
    c4_reasons+=" the three state files are not all distinct (unique=$uniq);"
  fi
fi
if [ -z "$c4_reasons" ]; then
  ok "each env has its own terraform.tfstate and the three are distinct"
else
  bad "states not isolated" "$c4_reasons"
fi

# ----- Check 5: each state mentions its own env and NOT the other envs' names
c5_reasons=""
for env in dev stg prod; do
  s="$WORK/envs/$env/terraform.tfstate"
  if [ ! -f "$s" ]; then
    c5_reasons+=" envs/$env/terraform.tfstate missing;"
    continue
  fi
  if ! grep -q "\"env\": \"$env\"" "$s" && ! grep -q "\"environment\": \"$env\"" "$s"; then
    c5_reasons+=" envs/$env/terraform.tfstate does not reference env '$env';"
    continue
  fi
  for other in dev stg prod; do
    [ "$other" = "$env" ] && continue
    if grep -q "\"env\": \"$other\"" "$s"; then
      c5_reasons+=" envs/$env/terraform.tfstate leaks env '$other';"
    fi
  done
done
if [ -z "$c5_reasons" ]; then
  ok "each state references only its own environment"
else
  bad "state scoping broken" "$c5_reasons"
fi

# ----- Check 6: terraform plan is clean (no changes) in all three envs
c6_reasons=""
for env in dev stg prod; do
  d="$WORK/envs/$env"
  if [ ! -d "$d/.terraform" ]; then
    c6_reasons+=" envs/$env not initialized;"
    continue
  fi
  # -detailed-exitcode: 0 = no changes, 2 = changes, 1 = error.
  (cd "$d" && "$TF_BIN" plan -detailed-exitcode -input=false -no-color -lock=false >/dev/null 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    c6_reasons+=" envs/$env plan not clean (exit=$rc, expected 0);"
  fi
done
if [ -z "$c6_reasons" ]; then
  ok "terraform plan is clean in dev, stg, and prod"
else
  bad "plan not idempotent" "$c6_reasons"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
