#!/usr/bin/env bash
# Structural validation for aws-17-01-landing-zone-minimal-adr.
# Checks that LANDING-ZONE-ADR.md exists and covers the required sections,
# accounts, SCPs, network pattern and alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-17-landing-zone}"
DOC="$BASE/LANDING-ZONE-ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section 1 — Contexto.
if grep -qiE '^#+ *(Secci[óo]n +1|Contexto|1\. +Contexto)' "$DOC"; then
  echo "  OK   has Contexto section"
else
  echo "  FAIL missing Contexto section"
  fail=$((fail+1))
fi

# Section 2 — Decision.
if grep -qiE '^#+ *(Secci[óo]n +2|Decisi[óo]n|2\. +Decisi[óo]n)' "$DOC"; then
  echo "  OK   has Decision section"
else
  echo "  FAIL missing Decision section"
  fail=$((fail+1))
fi

# Section 3 — Estructura de cuentas.
if grep -qiE '^#+ *(Secci[óo]n +3|Estructura|Cuentas|OUs?)' "$DOC"; then
  echo "  OK   has Estructura/Cuentas section"
else
  echo "  FAIL missing Estructura/Cuentas section"
  fail=$((fail+1))
fi

# Section 4 — Red.
if grep -qiE '^#+ *(Secci[óo]n +4|Red|Network)' "$DOC"; then
  echo "  OK   has Red/Network section"
else
  echo "  FAIL missing Red/Network section"
  fail=$((fail+1))
fi

# Section 5 — SCPs.
if grep -qiE '^#+ *(Secci[óo]n +5|SCPs?|Service Control Polic)' "$DOC"; then
  echo "  OK   has SCPs section"
else
  echo "  FAIL missing SCPs section"
  fail=$((fail+1))
fi

# Section 6 — Logging.
if grep -qiE '^#+ *(Secci[óo]n +6|Logging|Governance|Observabilidad)' "$DOC"; then
  echo "  OK   has Logging/Governance section"
else
  echo "  FAIL missing Logging/Governance section"
  fail=$((fail+1))
fi

# Section 7 — Alternativas.
if grep -qiE '^#+ *(Secci[óo]n +7|Alternativas)' "$DOC"; then
  echo "  OK   has Alternativas section"
else
  echo "  FAIL missing Alternativas section"
  fail=$((fail+1))
fi

# Section 8 — Consecuencias.
if grep -qiE '^#+ *(Secci[óo]n +8|Consecuencias|Consequences)' "$DOC"; then
  echo "  OK   has Consecuencias section"
else
  echo "  FAIL missing Consecuencias section"
  fail=$((fail+1))
fi

# Required accounts.
accounts_found=0
for acc in "management" "log-archive" "audit" "network" "shared-services" \
           "workload-dev" "workload-stg" "workload-prd"; do
  if grep -qi "$acc" "$DOC"; then
    accounts_found=$((accounts_found+1))
  fi
done
if [ "$accounts_found" -ge 6 ]; then
  echo "  OK   names at least 6 canonical accounts ($accounts_found found)"
else
  echo "  FAIL names only $accounts_found canonical accounts (expected >=6)"
  fail=$((fail+1))
fi

# Transit Gateway must be mentioned.
if grep -qiE 'transit gateway|\btgw\b' "$DOC"; then
  echo "  OK   mentions Transit Gateway"
else
  echo "  FAIL does not mention Transit Gateway"
  fail=$((fail+1))
fi

# Inspection VPC or central NAT must be mentioned.
if grep -qiE 'inspection vpc|nat central|central nat|nat centralizad'  "$DOC"; then
  echo "  OK   mentions inspection VPC / NAT central"
else
  echo "  FAIL does not mention inspection VPC / central NAT"
  fail=$((fail+1))
fi

# At least 3 SCPs: look for list items with 'SCP' or deny- prefixes or numbered 1./2./3.
scp_mentions=$(grep -ciE '\b(scp|service control|deny-|require-)' "$DOC" || true)
if [ "$scp_mentions" -ge 3 ]; then
  echo "  OK   has at least 3 SCP mentions ($scp_mentions)"
else
  echo "  FAIL has only $scp_mentions SCP mentions (expected >=3)"
  fail=$((fail+1))
fi

# At least 2 alternatives: look for 'Alternativa' lines.
alt_count=$(grep -ciE '^.*alternativa' "$DOC" || true)
if [ "$alt_count" -ge 2 ]; then
  echo "  OK   lists at least 2 alternatives ($alt_count mentions)"
else
  echo "  FAIL lists only $alt_count alternative mentions (expected >=2)"
  fail=$((fail+1))
fi

# Must mention CloudTrail (centralised logging).
if grep -qi 'cloudtrail' "$DOC"; then
  echo "  OK   mentions CloudTrail"
else
  echo "  FAIL does not mention CloudTrail"
  fail=$((fail+1))
fi

# Must mention Security Hub or GuardDuty or Config (governance).
if grep -qiE 'security hub|guardduty|\bconfig\b'  "$DOC"; then
  echo "  OK   mentions Security Hub / GuardDuty / Config"
else
  echo "  FAIL does not mention Security Hub / GuardDuty / Config"
  fail=$((fail+1))
fi

# Must mention cost trade-off (centralised NAT savings or TGW cost).
if grep -qiE 'coste|cost\b|nat.*(ahorr|savings|cheap)|ahorro' "$DOC"; then
  echo "  OK   mentions cost trade-off"
else
  echo "  FAIL does not mention any cost trade-off"
  fail=$((fail+1))
fi

# Must mention OUs.
if grep -qiE '\bOUs?\b|unidad(es)? organizativ' "$DOC"; then
  echo "  OK   mentions OUs"
else
  echo "  FAIL does not mention OUs"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara LANDING-ZONE-ADR.md con solution/REFERENCE.md para autoevaluarte."
exit 0
