#!/usr/bin/env bash
# Structural validation for aws-13-01-publish-site-with-cf-acm-route53.
# Checks the 5 artifacts: main.tf, distribution.json, ACM_DNS_WALKTHROUGH.md,
# CACHE_ORDER_ADR.md, COSTS.md.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Semantic correctness is NOT graded — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-13-publish}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and produce the 5 artifacts."
  exit 1
fi

# --- 1) main.tf ---------------------------------------------------------------
TF="$BASE/main.tf"
if [ ! -f "$TF" ]; then
  echo "  FAIL main.tf missing"
  fail=$((fail+1))
else
  echo "  OK   main.tf exists"
  # Two aliased providers (us-east-1 for ACM/CloudFront + another region)
  providers=$(grep -cE '^[[:space:]]*provider[[:space:]]+"aws"' "$TF")
  if [ "$providers" -ge 2 ]; then
    echo "  OK   main.tf declares at least 2 aws providers ($providers found)"
  else
    echo "  FAIL main.tf has $providers aws providers (expected >=2 for us-east-1 + home region)"
    fail=$((fail+1))
  fi
  if grep -qE 'region[[:space:]]*=[[:space:]]*"us-east-1"' "$TF"; then
    echo "  OK   main.tf references us-east-1 (required for ACM+CloudFront)"
  else
    echo "  FAIL main.tf does not reference us-east-1 provider"
    fail=$((fail+1))
  fi
  # Required resources
  for res in \
      "aws_s3_bucket" \
      "aws_s3_bucket_public_access_block" \
      "aws_cloudfront_origin_access_control" \
      "aws_acm_certificate" \
      "aws_cloudfront_distribution" \
      "aws_route53_zone" \
      "aws_route53_record"; do
    if grep -qE "resource[[:space:]]+\"${res}\"" "$TF"; then
      echo "  OK   main.tf declares ${res}"
    else
      echo "  FAIL main.tf missing resource ${res}"
      fail=$((fail+1))
    fi
  done
  # OAC-era signals (not legacy OAI)
  if grep -q 'origin_access_control_id' "$TF"; then
    echo "  OK   main.tf uses origin_access_control_id (OAC, not legacy OAI)"
  else
    echo "  FAIL main.tf does not reference origin_access_control_id"
    fail=$((fail+1))
  fi
  # ACM cert bound to us-east-1 provider alias
  if grep -qE 'aws_acm_certificate' "$TF" && \
     awk '/resource[[:space:]]+"aws_acm_certificate"/,/^}/' "$TF" | grep -qE 'provider[[:space:]]*=[[:space:]]*aws\.'; then
    echo "  OK   aws_acm_certificate pinned to a provider alias (expected us-east-1)"
  else
    echo "  FAIL aws_acm_certificate has no explicit provider = aws.<alias>"
    fail=$((fail+1))
  fi
  # TLS 1.2 minimum
  if grep -qE 'minimum_protocol_version[[:space:]]*=[[:space:]]*"TLSv1\.2' "$TF"; then
    echo "  OK   minimum_protocol_version >= TLSv1.2"
  else
    echo "  FAIL minimum_protocol_version not set to TLSv1.2* in main.tf"
    fail=$((fail+1))
  fi
  # redirect-to-https on default behavior
  if grep -q 'redirect-to-https' "$TF"; then
    echo "  OK   main.tf uses redirect-to-https"
  else
    echo "  FAIL main.tf missing redirect-to-https"
    fail=$((fail+1))
  fi
fi

# --- 2) distribution.json ----------------------------------------------------
JSON="$BASE/distribution.json"
if [ ! -f "$JSON" ]; then
  echo "  FAIL distribution.json missing"
  fail=$((fail+1))
else
  echo "  OK   distribution.json exists"
  if ! command -v jq >/dev/null 2>&1; then
    echo "  FAIL 'jq' not installed — required to validate distribution.json"
    fail=$((fail+1))
  else
    if ! jq empty "$JSON" >/dev/null 2>&1; then
      echo "  FAIL distribution.json is not valid JSON"
      fail=$((fail+1))
    else
      echo "  OK   distribution.json parses as JSON"

      aliases_count=$(jq -r '.DistributionConfig.Aliases.Items | length // 0' "$JSON" 2>/dev/null || echo 0)
      if [ "${aliases_count:-0}" -ge 1 ]; then
        echo "  OK   DistributionConfig.Aliases.Items has >=1 alias ($aliases_count)"
      else
        echo "  FAIL DistributionConfig.Aliases.Items empty"
        fail=$((fail+1))
      fi

      oac_id=$(jq -r '.DistributionConfig.Origins.Items[0].OriginAccessControlId // ""' "$JSON" 2>/dev/null || echo "")
      if [ -n "$oac_id" ]; then
        echo "  OK   Origins.Items[0].OriginAccessControlId is non-empty ($oac_id)"
      else
        echo "  FAIL Origins.Items[0].OriginAccessControlId empty (OAC missing)"
        fail=$((fail+1))
      fi

      vpp=$(jq -r '.DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy // ""' "$JSON" 2>/dev/null || echo "")
      if [ "$vpp" = "redirect-to-https" ]; then
        echo "  OK   DefaultCacheBehavior.ViewerProtocolPolicy == redirect-to-https"
      else
        echo "  FAIL DefaultCacheBehavior.ViewerProtocolPolicy is '$vpp' (expected redirect-to-https)"
        fail=$((fail+1))
      fi

      acm_arn=$(jq -r '.DistributionConfig.ViewerCertificate.ACMCertificateArn // ""' "$JSON" 2>/dev/null || echo "")
      case "$acm_arn" in
        arn:aws:acm:us-east-1:*)
          echo "  OK   ViewerCertificate.ACMCertificateArn is in us-east-1"
          ;;
        *)
          echo "  FAIL ACMCertificateArn '$acm_arn' not in us-east-1"
          fail=$((fail+1))
          ;;
      esac

      minver=$(jq -r '.DistributionConfig.ViewerCertificate.MinimumProtocolVersion // ""' "$JSON" 2>/dev/null || echo "")
      case "$minver" in
        TLSv1.2*|TLSv1.3*)
          echo "  OK   MinimumProtocolVersion >= TLSv1.2 ($minver)"
          ;;
        *)
          echo "  FAIL MinimumProtocolVersion '$minver' is below TLSv1.2"
          fail=$((fail+1))
          ;;
      esac
    fi
  fi
fi

# --- 3) ACM_DNS_WALKTHROUGH.md ------------------------------------------------
ACMDOC="$BASE/ACM_DNS_WALKTHROUGH.md"
if [ ! -f "$ACMDOC" ]; then
  echo "  FAIL ACM_DNS_WALKTHROUGH.md missing"
  fail=$((fail+1))
else
  echo "  OK   ACM_DNS_WALKTHROUGH.md exists"
  steps=0
  for n in 1 2 3 4 5; do
    if grep -Eq "^[[:space:]]*${n}\\." "$ACMDOC"; then
      steps=$((steps+1))
    fi
  done
  if [ "$steps" -ge 5 ]; then
    echo "  OK   ACM_DNS_WALKTHROUGH.md has at least 5 numbered steps"
  else
    echo "  FAIL ACM_DNS_WALKTHROUGH.md has $steps numbered steps (expected >=5)"
    fail=$((fail+1))
  fi
  for kw in "CNAME" "PENDING_VALIDATION" "ISSUED"; do
    if grep -q "$kw" "$ACMDOC"; then
      echo "  OK   ACM_DNS_WALKTHROUGH.md mentions $kw"
    else
      echo "  FAIL ACM_DNS_WALKTHROUGH.md does not mention $kw"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'renovaci[óo]n[[:space:]]+autom[áa]tica|automatic renewal' "$ACMDOC"; then
    echo "  OK   mentions automatic renewal / renovacion automatica"
  else
    echo "  FAIL does not mention automatic renewal"
    fail=$((fail+1))
  fi
fi

# --- 4) CACHE_ORDER_ADR.md ---------------------------------------------------
ADR="$BASE/CACHE_ORDER_ADR.md"
if [ ! -f "$ADR" ]; then
  echo "  FAIL CACHE_ORDER_ADR.md missing"
  fail=$((fail+1))
else
  echo "  OK   CACHE_ORDER_ADR.md exists"
  for sect in "Context" "Decision" "Consequences"; do
    if grep -qiE "^#+[[:space:]]*${sect}" "$ADR"; then
      echo "  OK   CACHE_ORDER_ADR.md has '${sect}' section"
    else
      echo "  FAIL CACHE_ORDER_ADR.md missing '${sect}' section"
      fail=$((fail+1))
    fi
  done
  patterns=0
  for p in '/api/\*' '/private/\*' '/static/\*'; do
    if grep -Eq "$p" "$ADR"; then
      patterns=$((patterns+1))
    fi
  done
  if [ "$patterns" -ge 3 ]; then
    echo "  OK   ADR lists 3 specific path patterns"
  else
    echo "  FAIL ADR lists only $patterns of /api/*, /private/*, /static/*"
    fail=$((fail+1))
  fi
  if grep -qiE 'espec[íi]fico|specific|order|orden' "$ADR"; then
    echo "  OK   ADR discusses ordering / specificity"
  else
    echo "  FAIL ADR does not discuss ordering / specificity"
    fail=$((fail+1))
  fi
fi

# --- 5) COSTS.md -------------------------------------------------------------
COSTS="$BASE/COSTS.md"
if [ ! -f "$COSTS" ]; then
  echo "  FAIL COSTS.md missing"
  fail=$((fail+1))
else
  echo "  OK   COSTS.md exists"
  if grep -qE '0[.,]50[[:space:]]*USD|\$0[.,]50|0\.50/mo' "$COSTS"; then
    echo "  OK   COSTS.md mentions 0.50 USD hosted zone cost"
  else
    echo "  FAIL COSTS.md does not mention 0.50 USD hosted zone cost"
    fail=$((fail+1))
  fi
  if grep -qiE 'acm.*gratis|acm.*free|free.*acm|gratis.*acm' "$COSTS"; then
    echo "  OK   COSTS.md states ACM public is free"
  else
    echo "  FAIL COSTS.md does not state ACM public is free"
    fail=$((fail+1))
  fi
  if grep -qiE 'no[[:space:]]+se[[:space:]]+aplica|does not apply|not applied' "$COSTS"; then
    echo "  OK   COSTS.md explicitly states 'no se aplica'"
  else
    echo "  FAIL COSTS.md does not state 'no se aplica' explicitly"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara los 5 artefactos con solution/REFERENCE.md para autoevaluarte."
exit 0
