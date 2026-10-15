#!/usr/bin/env bash
# Validator for dkr-14-02-fail-build-on-critical-cve.
#
# NOTE: deliberately NOT using `set -o pipefail` because we pipe docker and
# grep heavily; SIGPIPE (141) would mark correct checks as failures.

BASE="${1:-${BASE_DIR:-/tmp/dkr-14-02}}"
IMAGE="dkr-14-02-vuln:v1"

pass=0
fail=0
skip=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }
skp() { report+="  SKIP — $1\n"; skip=$((skip+1)); }

echo "== Validating dkr-14-02 under $BASE =="

if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE. Run starter/bootstrap.sh first."
  echo; printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
ok "base dir present"

for f in Dockerfile scan.sh; do
  if [ -f "$BASE/$f" ]; then ok "$f present"; else bad "$f missing at $BASE/$f"; fi
done

if [ -f "$BASE/scan.sh" ]; then
  if [ -x "$BASE/scan.sh" ]; then
    ok "scan.sh is executable"
  else
    bad "scan.sh is NOT executable (chmod +x)"
  fi

  if grep -qE -- "--severity[= ]+(CRITICAL|CRITICAL,HIGH|HIGH,CRITICAL)" "$BASE/scan.sh"; then
    ok "scan.sh uses --severity CRITICAL"
  else
    bad "scan.sh does not use --severity CRITICAL"
  fi

  if grep -qE -- "--exit-code[= ]+1" "$BASE/scan.sh"; then
    ok "scan.sh uses --exit-code 1 (gate)"
  else
    bad "scan.sh does not use --exit-code 1 — gate will not block"
  fi

  # Flag only non-comment pipefail directives
  if grep -qE "^[[:space:]]*set [^#]*pipefail" "$BASE/scan.sh" && grep -qE "^[[:space:]]*[^#].*grep -q" "$BASE/scan.sh"; then
    bad "scan.sh uses 'set -o pipefail' combined with 'grep -q' (anti-pattern of the course)"
  else
    ok "scan.sh avoids pipefail+grep -q pitfall"
  fi
fi

have_docker=0; have_trivy=0
command -v docker >/dev/null 2>&1 && have_docker=1
command -v trivy  >/dev/null 2>&1 && have_trivy=1
echo "  (runtime tools: docker=$have_docker trivy=$have_trivy)"

if [ $have_docker -eq 0 ] || ! docker info >/dev/null 2>&1; then
  skp "docker not available — runtime gate check skipped"
elif [ $have_trivy -eq 0 ]; then
  skp "trivy not installed — runtime gate check skipped"
else
  # Build if needed
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -q -t "$IMAGE" "$BASE" >/dev/null 2>&1 || true
  fi

  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    set +e
    bash "$BASE/scan.sh" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      ok "scan.sh exits non-zero on deliberately vulnerable image (rc=$rc)"
    else
      bad "scan.sh exited 0 on deliberately vulnerable image — gate not working"
    fi
  else
    skp "image $IMAGE not built — gate not exercised"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass OK / $skip SKIP)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
