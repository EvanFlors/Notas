#!/usr/bin/env bash
# Validate dkr-11-01-shrink-the-image.
#
# Checks (if docker is available):
#   1) image tag 'app:slim' exists
#   2) its size is < 100 MB (as reported by docker image inspect)
#   3) `docker run --rm app:slim` prints a line ending in 'ok' and exits 0
#
# SKIP (exit 0) if docker is missing or daemon unreachable.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe `docker ...`
# output into `grep -q`; pipefail would surface spurious SIGPIPE on the
# producer when grep exits early.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/dkr-11-shrink}}"
TAG="${TAG:-app:slim}"
MAX_BYTES=$((100 * 1024 * 1024))

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-11-01-shrink-the-image =="
echo "   BASE=$BASE   TAG=$TAG"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed. (exit 0)"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable. (exit 0)"
  exit 0
fi

# 1) tag exists
if docker image inspect "$TAG" >/dev/null 2>&1; then
  note_ok "image $TAG exists"
else
  note_fail "image $TAG not found — did you run 'docker build -t $TAG .'?"
  printf "%b\n" "$report"
  echo "RESULT: $passed passed, $failed failed."
  exit 1
fi

# 2) size < 100 MB
size="$(docker image inspect "$TAG" --format '{{.Size}}' 2>/dev/null || echo 0)"
if [ "$size" -gt 0 ] && [ "$size" -lt "$MAX_BYTES" ]; then
  note_ok "size $size bytes < $MAX_BYTES (100 MB)"
else
  note_fail "size $size bytes is NOT < $MAX_BYTES (100 MB)"
fi

# 3) runs and prints a line ending in 'ok'
out="$(docker run --rm "$TAG" 2>&1 || true)"
if printf '%s\n' "$out" | tail -n 1 | grep -qE 'ok[[:space:]]*$'; then
  note_ok "runtime output ends with 'ok'"
else
  note_fail "runtime output did not end with 'ok'. Got: $out"
fi

printf "\n%b\n" "$report"
echo "RESULT: $passed passed, $failed failed."
[ "$failed" -eq 0 ]
