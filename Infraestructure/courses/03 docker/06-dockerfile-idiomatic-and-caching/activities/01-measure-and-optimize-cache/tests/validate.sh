#!/usr/bin/env bash
# Validate the learner's fixed Dockerfile in /tmp/dkr-06-01/.
# Checks:
#   1. Image builds cleanly.
#   2. Warm rebuild after touching app.py keeps pip install cached
#      (verified via docker history: pip install step comes from cache).
#   3. Warm rebuild time is under 5 seconds.
#
# Note: no `set -o pipefail` on purpose — we use `grep -q` on docker output
# and SIGPIPE on the producer side would spuriously flip a successful probe
# into a failure. See the pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh

set -eu

BASE="${BASE_DIR:-/tmp/dkr-06-01}"
IMG="cache-lab:latest"
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

echo "== Check 1: cold build succeeds =="
docker rmi "$IMG" >/dev/null 2>&1 || true
if docker build --no-cache -t "$IMG" . >/tmp/dkr-06-01-cold.log 2>&1; then
  report+="Check 1 (cold build): OK\n"
  passed=$((passed+1))
else
  report+="Check 1 (cold build): FAIL — see /tmp/dkr-06-01-cold.log\n"
  failed=$((failed+1))
fi

echo "== Check 2: warm rebuild caches pip install =="
# Touch app.py to simulate a code edit.
printf '\n' >> app.py

# Capture time (seconds) and plain output in one build.
start_ns=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
docker build --progress=plain -t "$IMG" . >/tmp/dkr-06-01-warm.log 2>&1
end_ns=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

# Revert the touch so the file is clean.
python3 - <<'PY'
from pathlib import Path
p = Path("app.py")
text = p.read_text()
# Strip exactly one trailing blank line if present.
if text.endswith("\n\n"):
    p.write_text(text[:-1])
PY

# Did pip install come from cache? Look for a CACHED marker on that step.
if grep -E "CACHED.*pip install" /tmp/dkr-06-01-warm.log >/dev/null 2>&1; then
  report+="Check 2 (pip install cached on warm rebuild): OK\n"
  passed=$((passed+1))
else
  report+="Check 2 (pip install cached on warm rebuild): FAIL — pip install re-ran. Reorder the Dockerfile so requirements.txt is copied BEFORE the source code.\n"
  failed=$((failed+1))
fi

echo "== Check 3: warm rebuild under 5 seconds =="
if [ "$elapsed_ms" -lt 5000 ]; then
  report+="Check 3 (warm rebuild < 5000 ms): OK (${elapsed_ms} ms)\n"
  passed=$((passed+1))
else
  report+="Check 3 (warm rebuild < 5000 ms): FAIL (${elapsed_ms} ms). On a cold environment the first warm rebuild may need a retry; try running the validator again.\n"
  failed=$((failed+1))
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 checks OK."

if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
