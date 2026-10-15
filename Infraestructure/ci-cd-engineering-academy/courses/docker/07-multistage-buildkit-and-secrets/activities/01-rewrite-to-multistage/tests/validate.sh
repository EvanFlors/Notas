#!/usr/bin/env bash
# Validate the learner's multi-stage rewrite under /tmp/dkr-07-01.
#
# Checks:
#   1. Dockerfile starts with `# syntax=docker/dockerfile:1`.
#   2. Dockerfile has >= 2 FROM lines and >= 1 COPY --from=.
#   3. Image builds cleanly.
#   4. Final image size < 150 MB.
#   5. No gcc in the final image.
#   6. App responds to GET /health with 200.
#
# Note: no `set -o pipefail` on purpose — we use `grep -q` on docker output
# and SIGPIPE on the producer would spuriously flip success into failure.
# See the pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh

set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-01}"
IMG="multistage-lab:latest"
CONTAINER="dkr-07-01-smoke"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

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

echo "== Check 1: Dockerfile has `# syntax=docker/dockerfile:1` =="
if head -1 Dockerfile | grep -q "^# syntax=docker/dockerfile:1"; then
  note_ok "primera linea tiene '# syntax=docker/dockerfile:1'"
else
  note_fail "primera linea NO tiene '# syntax=docker/dockerfile:1'"
fi

echo "== Check 2: structure (>=2 FROM, >=1 COPY --from=) =="
from_count="$(grep -c -E "^FROM " Dockerfile || true)"
copyfrom_count="$(grep -c -E "COPY[[:space:]]+--from=" Dockerfile || true)"
if [ "$from_count" -ge 2 ]; then
  note_ok "Dockerfile tiene $from_count FROM (>=2)"
else
  note_fail "Dockerfile solo tiene $from_count FROM (se esperan >=2)"
fi
if [ "$copyfrom_count" -ge 1 ]; then
  note_ok "Dockerfile tiene $copyfrom_count COPY --from="
else
  note_fail "Dockerfile no tiene COPY --from= (requerido para multi-stage util)"
fi

echo "== Check 3: build =="
docker rmi "$IMG" >/dev/null 2>&1 || true
if docker build -t "$IMG" . >/tmp/dkr-07-01-build.log 2>&1; then
  note_ok "docker build OK"
else
  note_fail "docker build FAIL (ver /tmp/dkr-07-01-build.log)"
  # Early-return the rest since subsequent checks need the image.
  echo
  printf "%b" "$report"
  echo
  total=$((passed + failed))
  echo "RESULT: $passed/$total checks OK."
  exit 1
fi

echo "== Check 4: image size < 150 MB =="
size_bytes="$(docker image inspect "$IMG" --format '{{.Size}}' 2>/dev/null || echo 0)"
# Convert to MB (SI, 1 MB = 1_000_000 bytes — matches `docker images` display).
size_mb=$(( size_bytes / 1000000 ))
if [ "$size_mb" -lt 150 ] && [ "$size_mb" -gt 0 ]; then
  note_ok "imagen final = ${size_mb} MB (< 150 MB)"
else
  note_fail "imagen final = ${size_mb} MB (se esperan < 150 MB)"
fi

echo "== Check 5: no gcc in final image =="
if docker run --rm --entrypoint sh "$IMG" -c "command -v gcc >/dev/null 2>&1"; then
  note_fail "gcc esta presente en la imagen final (deberia estar solo en builder)"
else
  note_ok "gcc NO esta en la imagen final"
fi

echo "== Check 6: app responds to /health =="
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
# Pick a random free-ish port.
PORT=18000
docker run -d --name "$CONTAINER" -p "${PORT}:8000" "$IMG" >/dev/null
# Give it time to start.
app_ok=0
for i in $(seq 1 30); do
  sleep 1
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/health" 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then
    app_ok=1
    break
  fi
done
if [ "$app_ok" -ne 1 ]; then
  echo "  INFO -- app no respondio; ultimos logs del contenedor:" >&2
  docker logs --tail 20 "$CONTAINER" 2>&1 | sed 's/^/    /' >&2 || true
fi
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
if [ "$app_ok" -eq 1 ]; then
  note_ok "GET /health respondio 200"
else
  note_fail "GET /health no respondio 200 en 30 s (ver logs arriba)"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
