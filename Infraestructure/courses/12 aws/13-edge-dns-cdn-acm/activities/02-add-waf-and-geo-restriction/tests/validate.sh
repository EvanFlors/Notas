#!/usr/bin/env bash
# Structural validation for aws-13-02-add-waf-and-geo-restriction.
# Checks that WAF_DESIGN.md has the 4 sections, 3+ rules, geo decision
# with trade-offs, cost figures, and limitations list.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Semantic correctness is NOT graded — compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-13-waf}"
DOC="$BASE/WAF_DESIGN.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# 4 sections (match "Secci[óo]n N" or an english keyword)
for n in 1 2 3 4; do
  if grep -qiE "^#+[[:space:]]*(Secci[óo]n[[:space:]]*${n}|Section[[:space:]]*${n})" "$DOC"; then
    echo "  OK   WAF_DESIGN.md has Section ${n}"
  else
    echo "  FAIL WAF_DESIGN.md missing Section ${n} heading"
    fail=$((fail+1))
  fi
done

# At least 3 numbered rules (1., 2., 3.) in the first part of the doc.
rules_found=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    rules_found=$((rules_found+1))
  fi
done
if [ "$rules_found" -ge 3 ]; then
  echo "  OK   WAF_DESIGN.md has at least 3 numbered rules"
else
  echo "  FAIL WAF_DESIGN.md has $rules_found numbered rules (expected >=3)"
  fail=$((fail+1))
fi

# At least one of 'managed', 'rate', 'geo' in rules.
if grep -qiE 'managed|rate|geo' "$DOC"; then
  echo "  OK   WAF_DESIGN.md mentions managed/rate/geo rule type"
else
  echo "  FAIL WAF_DESIGN.md does not mention managed/rate/geo rule type"
  fail=$((fail+1))
fi

# Must mention CloudFront AND WAF in Geo decision context.
if grep -qi 'cloudfront' "$DOC"; then
  echo "  OK   mentions CloudFront"
else
  echo "  FAIL does not mention CloudFront"
  fail=$((fail+1))
fi
if grep -qiE '\bwaf\b' "$DOC"; then
  echo "  OK   mentions WAF"
else
  echo "  FAIL does not mention WAF"
  fail=$((fail+1))
fi

# Must have a "Decision" marker.
if grep -qiE 'decisi[óo]n|decision' "$DOC"; then
  echo "  OK   WAF_DESIGN.md has a Decision marker"
else
  echo "  FAIL WAF_DESIGN.md has no Decision marker"
  fail=$((fail+1))
fi

# Trade-offs: at least 2 occurrences of 'trade-off' / 'trade off' / 'ventaja' / 'desventaja'.
trade=$(grep -ciE 'trade[- ]off|ventaja|desventaja|pro[s]?|con[s]?' "$DOC")
if [ "$trade" -ge 2 ]; then
  echo "  OK   WAF_DESIGN.md discusses trade-offs ($trade mentions)"
else
  echo "  FAIL WAF_DESIGN.md has only $trade trade-off mentions (expected >=2)"
  fail=$((fail+1))
fi

# Cost section: must mention USD and the figures 5 and 0.60 (or 0,60).
if grep -q 'USD' "$DOC"; then
  echo "  OK   WAF_DESIGN.md mentions USD"
else
  echo "  FAIL WAF_DESIGN.md does not mention USD"
  fail=$((fail+1))
fi
if grep -qE '(^|[^0-9])5([[:space:]]|USD|[^0-9])' "$DOC"; then
  echo "  OK   WAF_DESIGN.md mentions the 5 USD/mo ACL cost"
else
  echo "  FAIL WAF_DESIGN.md does not mention the 5 USD web ACL figure"
  fail=$((fail+1))
fi
if grep -qE '0[.,]60' "$DOC"; then
  echo "  OK   WAF_DESIGN.md mentions the 0.60 USD per million figure"
else
  echo "  FAIL WAF_DESIGN.md does not mention the 0.60 USD figure"
  fail=$((fail+1))
fi

# Limitations: at least 5 numbered items somewhere in the doc.
lim_found=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    lim_found=$((lim_found+1))
  fi
done
if [ "$lim_found" -ge 5 ]; then
  echo "  OK   WAF_DESIGN.md has at least 5 numbered items (rules + limitations)"
else
  echo "  FAIL only $lim_found numbered items (expected >=5 across rules + limitations)"
  fail=$((fail+1))
fi

# Must mention 'shield' OR 'ddos' OR 'cognito' OR 'iam' OR 'rate limit' as a limitation hint.
if grep -qiE 'shield|ddos|cognito|\biam\b|rate[- ]?limit' "$DOC"; then
  echo "  OK   WAF_DESIGN.md mentions out-of-scope responsibilities (Shield/DDoS/Cognito/IAM/rate limit)"
else
  echo "  FAIL WAF_DESIGN.md does not mention out-of-scope responsibilities"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara WAF_DESIGN.md con solution/REFERENCE.md para autoevaluarte."
exit 0
