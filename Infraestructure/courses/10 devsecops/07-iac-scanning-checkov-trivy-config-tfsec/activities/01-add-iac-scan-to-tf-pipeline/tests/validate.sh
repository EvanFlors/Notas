#!/usr/bin/env bash
# Structural validation for sec-07-01-add-iac-scan-to-tf-pipeline.
#
# Note: we deliberately do NOT enable `set -o pipefail` — several checks use
# `jq ... | grep -q` and `grep ... | head`, which trigger SIGPIPE (exit 141)
# on early match. pipefail would surface that as a spurious FAIL.
set -eu

BASE="${1:-/tmp/sec-07-iac-pipeline}"
fail=0

echo "== Structural validation for $BASE =="

# ----- 1. Workspace exists with starter laid down -----
for p in "scan.sh" "suppressions.csv" "terraform/main.tf" "k8s/bad-pod.yaml"; do
  if [ -e "$BASE/$p" ]; then
    echo "  OK   present: $p"
  else
    echo "  FAIL missing: $p"
    fail=$((fail+1))
  fi
done

# ----- 2. scan.sh hygiene -----
if [ -x "$BASE/scan.sh" ]; then
  echo "  OK   scan.sh is executable"
else
  echo "  FAIL scan.sh is not executable (chmod +x scan.sh)"
  fail=$((fail+1))
fi

if grep -qE '^[[:space:]]*set[[:space:]].*pipefail' "$BASE/scan.sh" 2>/dev/null; then
  echo "  FAIL scan.sh enables 'set -o pipefail' (forbidden: SIGPIPE false positives)"
  fail=$((fail+1))
else
  echo "  OK   scan.sh does not enable pipefail (comments mentioning it are fine)"
fi

if grep -qE '^set -eu' "$BASE/scan.sh" 2>/dev/null; then
  echo "  OK   scan.sh uses 'set -eu'"
else
  echo "  FAIL scan.sh must start with 'set -eu'"
  fail=$((fail+1))
fi

# ----- 3. suppressions.csv header -----
if head -n1 "$BASE/suppressions.csv" 2>/dev/null | grep -qE '^rule_id,reason,expires'; then
  echo "  OK   suppressions.csv has required header (rule_id,reason,expires)"
else
  echo "  FAIL suppressions.csv header must be exactly: rule_id,reason,expires"
  fail=$((fail+1))
fi

# ----- 4. REPORT.md exists; if not, try to generate it by running scan.sh -----
if [ ! -f "$BASE/REPORT.md" ]; then
  echo "  INFO REPORT.md absent; attempting to generate by running scan.sh ..."
  if [ -x "$BASE/scan.sh" ]; then
    # scan.sh exits 1 when there are blocking findings — that's fine for us.
    ( cd "$BASE" && ./scan.sh ) >/dev/null 2>&1 || true
  fi
fi

if [ -f "$BASE/REPORT.md" ]; then
  echo "  OK   REPORT.md exists"
  for sec in "## Resumen" "## Checkov" "## Trivy config" "## Suprimidos"; do
    if grep -qF "$sec" "$BASE/REPORT.md"; then
      echo "  OK   REPORT.md has section: $sec"
    else
      echo "  FAIL REPORT.md missing section: $sec"
      fail=$((fail+1))
    fi
  done
else
  echo "  FAIL REPORT.md was not produced"
  fail=$((fail+1))
fi

# ----- 5. Smoke: scan.sh runs twice without dirtying state -----
if [ -x "$BASE/scan.sh" ]; then
  ( cd "$BASE" && ./scan.sh ) >/dev/null 2>&1 || true
  size1=$(wc -c < "$BASE/REPORT.md" 2>/dev/null || echo 0)
  ( cd "$BASE" && ./scan.sh ) >/dev/null 2>&1 || true
  size2=$(wc -c < "$BASE/REPORT.md" 2>/dev/null || echo 0)
  if [ "$size1" = "$size2" ]; then
    echo "  OK   scan.sh is idempotent (REPORT.md size stable across runs)"
  else
    echo "  FAIL scan.sh is not idempotent (REPORT.md size: $size1 -> $size2)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Revisa REPORT.md y compara con solution/REFERENCE.md."
exit 0
