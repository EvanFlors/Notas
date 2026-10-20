#!/usr/bin/env bash
# Validate the ADD-vs-COPY activity in /tmp/dkr-06-02/.
# Checks:
#   1. Image builds.
#   2. /app/main.py exists (scenario A).
#   3. /opt/assets/README.txt exists (scenario B — tar extracted).
#   4. /opt/payload exists AND its sha256 matches assets/checksum.txt (scenario C).
#
# Note: no `set -o pipefail` — several checks use `grep -q` and we don't want
# SIGPIPE on upstream producers to spuriously fail passing checks.

set -eu

BASE="${BASE_DIR:-/tmp/dkr-06-02}"
IMG="addcopy-lab:latest"
passed=0
failed=0
report=""

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

if [ ! -f "$BASE/Dockerfile" ]; then
  echo "FAIL: $BASE/Dockerfile not found. Run starter/bootstrap.sh first." >&2
  exit 1
fi

cd "$BASE"

echo "== Check 1: build the image =="
if docker build -t "$IMG" . >/tmp/dkr-06-02-build.log 2>&1; then
  report+="Check 1 (build): OK\n"
  passed=$((passed+1))
else
  report+="Check 1 (build): FAIL — see /tmp/dkr-06-02-build.log\n"
  failed=$((failed+1))
  echo
  printf "%b" "$report"
  exit 1
fi

echo "== Check 2: /app/main.py present (scenario A) =="
if docker run --rm --entrypoint sh "$IMG" -c "test -f /app/main.py"; then
  report+="Check 2 (/app/main.py present): OK\n"
  passed=$((passed+1))
else
  report+="Check 2 (/app/main.py present): FAIL — did you COPY src/ to /app/?\n"
  failed=$((failed+1))
fi

echo "== Check 3: /opt/assets/README.txt present (scenario B) =="
if docker run --rm --entrypoint sh "$IMG" -c "test -f /opt/assets/README.txt"; then
  report+="Check 3 (/opt/assets/README.txt present): OK\n"
  passed=$((passed+1))
else
  report+="Check 3 (/opt/assets/README.txt present): FAIL — did ADD extract the tar into /opt/assets/?\n"
  failed=$((failed+1))
fi

echo "== Check 4: /opt/payload exists and sha256 matches =="
EXPECTED_SHA="$(awk '{print $1}' assets/checksum.txt)"
ACTUAL_SHA="$(docker run --rm --entrypoint sh "$IMG" -c "sha256sum /opt/payload | awk '{print \$1}'" 2>/dev/null || echo missing)"
if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
  report+="Check 4 (/opt/payload sha256 matches): OK\n"
  passed=$((passed+1))
else
  report+="Check 4 (/opt/payload sha256 matches): FAIL — expected $EXPECTED_SHA, got $ACTUAL_SHA\n"
  failed=$((failed+1))
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/4 checks OK."

if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
