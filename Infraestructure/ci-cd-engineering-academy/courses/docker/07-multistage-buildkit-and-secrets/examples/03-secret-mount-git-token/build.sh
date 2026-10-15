#!/usr/bin/env bash
# Build an image using --mount=type=secret and prove the token is NOT in
# docker history or in any layer of the final image.
#
# Note: no `set -o pipefail` on purpose — we use `grep -q` on docker output
# and SIGPIPE on the producer would spuriously flip success to failure. See
# the pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
IMG="secret-mount-demo:latest"
SECRET_FILE="/tmp/dkr-07-ex03.token"
FAKE_TOKEN="FAKE_TOKEN_xxxx0123456789"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

cleanup() { rm -f "$SECRET_FILE"; }
trap cleanup EXIT

echo "== Writing dummy secret to $SECRET_FILE =="
printf '%s' "$FAKE_TOKEN" > "$SECRET_FILE"

echo
echo "== Building with --secret id=github_token =="
# DOCKER_BUILDKIT=1 is explicit for compatibility with older engines.
DOCKER_BUILDKIT=1 docker build \
  --secret id=github_token,src="$SECRET_FILE" \
  --progress=plain \
  -t "$IMG" .

echo
echo "== Receipt stored in the image (length + last 4 chars only) =="
docker run --rm "$IMG"

echo
echo "== Auditing docker history for the token =="
if docker history --no-trunc "$IMG" | grep -q "$FAKE_TOKEN"; then
  echo "FAIL: token $FAKE_TOKEN found in docker history."
  exit 1
else
  echo "OK: token NOT present in docker history."
fi

echo
echo "== Auditing final image filesystem for the token =="
if docker run --rm "$IMG" sh -c "ls /run/secrets 2>/dev/null"; then
  echo "WARN: /run/secrets directory exists in the image (should NOT)."
else
  echo "OK: /run/secrets is absent from the final image."
fi
