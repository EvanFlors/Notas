#!/usr/bin/env bash
# Example 01 — build a FastAPI image and push it to a local registry:2
# that stands in for ECR. No real AWS calls.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI not available"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl not available"
  exit 0
fi

PORT="${REGISTRY_PORT:-5000}"
REG_NAME="aws10-ex01-registry"
IMAGE_LOCAL="aws10-fastapi-demo:local"
IMAGE_REMOTE="127.0.0.1:${PORT}/aws10-fastapi-demo:v1"

cleanup() {
  docker rm -f "$REG_NAME" >/dev/null 2>&1 || true
  docker rmi -f "$IMAGE_REMOTE" >/dev/null 2>&1 || true
  docker rmi -f "$IMAGE_LOCAL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 1. launch local registry (stand-in for ECR)
docker rm -f "$REG_NAME" >/dev/null 2>&1 || true
echo "== starting local registry at 127.0.0.1:${PORT}"
docker run -d --rm --name "$REG_NAME" -p "127.0.0.1:${PORT}:5000" registry:2 >/dev/null

for _ in $(seq 1 40); do
  if curl -fs "http://127.0.0.1:${PORT}/v2/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

if ! curl -fs "http://127.0.0.1:${PORT}/v2/" >/dev/null 2>&1; then
  echo "FAIL: local registry did not come up on 127.0.0.1:${PORT}"
  exit 1
fi

# 2. build the FastAPI image
echo "== building ${IMAGE_LOCAL}"
docker build -q -t "$IMAGE_LOCAL" . >/dev/null

# 3. tag + push to the local registry (same semantics as ECR push)
echo "== tagging as ${IMAGE_REMOTE}"
docker tag "$IMAGE_LOCAL" "$IMAGE_REMOTE"

echo "== pushing to the local registry (no login needed; ECR would require aws ecr get-login-password)"
docker push "$IMAGE_REMOTE" >/dev/null

# 4. interrogate the registry just like 'aws ecr describe-repositories / list-images'
echo
echo "== catalog (equivalent to aws ecr describe-repositories):"
curl -s "http://127.0.0.1:${PORT}/v2/_catalog"
echo
echo "== tags for aws10-fastapi-demo (equivalent to aws ecr list-images):"
curl -s "http://127.0.0.1:${PORT}/v2/aws10-fastapi-demo/tags/list"
echo

# 5. structural assertion
if curl -s "http://127.0.0.1:${PORT}/v2/_catalog" | grep -q "aws10-fastapi-demo"; then
  echo "OK: example 01 — image pushed to local registry (ECR-equivalent)"
  exit 0
else
  echo "FAIL: image not visible in registry catalog"
  exit 1
fi
