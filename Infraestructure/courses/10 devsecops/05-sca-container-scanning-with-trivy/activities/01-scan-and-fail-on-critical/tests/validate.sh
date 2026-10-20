#!/usr/bin/env bash
# Structural validation for sec-05-01-scan-and-fail-on-critical.
# Checks artifacts: Dockerfile, .trivyignore.yaml, POLICY.md, scan*.exit.
# Executable checks (docker/trivy) SKIP gracefully if the tools are missing.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-05-fail-on-critical}"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Student must create it."
  exit 1
fi

# ---------- Dockerfile ----------
DOCKERFILE="$BASE/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
  echo "  FAIL Dockerfile missing at $DOCKERFILE"
  fail=$((fail+1))
else
  echo "  OK   Dockerfile exists"
  if grep -qE '^FROM[[:space:]]+alpine:3\.14' "$DOCKERFILE"; then
    echo "  OK   Dockerfile uses FROM alpine:3.14 (deliberately old)"
  else
    echo "  FAIL Dockerfile does not use 'FROM alpine:3.14' (lab requires it to guarantee CVEs)"
    fail=$((fail+1))
  fi
  if grep -qE 'requests==2\.19\.0' "$DOCKERFILE"; then
    echo "  OK   Dockerfile installs requests==2.19.0 (language-layer vuln)"
  else
    echo "  FAIL Dockerfile does not install requests==2.19.0"
    fail=$((fail+1))
  fi
fi

# ---------- .trivyignore.yaml ----------
IGNORE="$BASE/.trivyignore.yaml"
if [ ! -f "$IGNORE" ]; then
  echo "  FAIL .trivyignore.yaml missing at $IGNORE"
  fail=$((fail+1))
else
  echo "  OK   .trivyignore.yaml exists"
  for key in "id:" "statement:" "expired_at:"; do
    if grep -qE "^[[:space:]]*-?[[:space:]]*${key}" "$IGNORE"; then
      echo "  OK   .trivyignore.yaml has key '${key%:}'"
    else
      echo "  FAIL .trivyignore.yaml missing required key '${key%:}'"
      fail=$((fail+1))
    fi
  done
  # CVE id must look like a CVE
  if grep -qiE 'CVE-[0-9]{4}-[0-9A-Za-z]+' "$IGNORE"; then
    echo "  OK   .trivyignore.yaml references at least one CVE id"
  else
    echo "  FAIL .trivyignore.yaml does not reference any CVE id"
    fail=$((fail+1))
  fi
fi

# ---------- POLICY.md ----------
POLICY="$BASE/POLICY.md"
if [ ! -f "$POLICY" ]; then
  echo "  FAIL POLICY.md missing at $POLICY"
  fail=$((fail+1))
else
  echo "  OK   POLICY.md exists"
  for section in "A" "B" "C"; do
    if grep -qiE "^#+ *(Secci[óo]n +${section}\b|${section}\. )" "$POLICY"; then
      echo "  OK   POLICY.md has Section ${section}"
    else
      echo "  FAIL POLICY.md missing Section ${section}"
      fail=$((fail+1))
    fi
  done
  for kw in "CRITICAL" "KEV" "EPSS" "ignore-unfixed"; do
    if grep -q "$kw" "$POLICY"; then
      echo "  OK   POLICY.md mentions '$kw'"
    else
      echo "  FAIL POLICY.md does not mention '$kw'"
      fail=$((fail+1))
    fi
  done
fi

# ---------- scan1.exit (should be exit=1) ----------
S1="$BASE/scan1.exit"
if [ ! -f "$S1" ]; then
  echo "  SKIP scan1.exit missing (did you run the first scan? docker/trivy required)"
  skipped=$((skipped+1))
else
  if grep -qx 'exit=1' "$S1"; then
    echo "  OK   scan1.exit records exit=1 (gate correctly blocked)"
  else
    echo "  FAIL scan1.exit does not contain 'exit=1' (first scan should have failed)"
    fail=$((fail+1))
  fi
fi

# ---------- scan2.exit (any exit code is acceptable, just must exist) ----------
S2="$BASE/scan2.exit"
if [ ! -f "$S2" ]; then
  echo "  SKIP scan2.exit missing (second scan not run; docker/trivy required)"
  skipped=$((skipped+1))
else
  if grep -qE '^exit=[0-9]+' "$S2"; then
    echo "  OK   scan2.exit records an exit code"
  else
    echo "  FAIL scan2.exit does not contain a recognizable 'exit=N' line"
    fail=$((fail+1))
  fi
fi

# ---------- Optional: docker/trivy availability signal ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "  SKIP docker not in PATH (executable checks were skipped above)"
fi
if ! command -v trivy >/dev/null 2>&1; then
  echo "  INFO trivy binary not in PATH — ok, the lab uses aquasec/trivy:0.56.2 via docker"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed, $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
if [ "$skipped" -gt 0 ]; then
  echo "OK (with $skipped skipped executable check(s)). Install docker to run the full lab."
else
  echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
fi
exit 0
