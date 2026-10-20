#!/usr/bin/env bash
# Hardened docker run for the FastAPI app.
set -eu

NAME="${NAME:-dkr13-01-app}"
IMAGE="${IMAGE:-dkr13-01:v1}"

docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$NAME" \
  --user 10001:10001 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --memory=256m \
  --memory-swap=256m \
  --pids-limit=100 \
  --cpus=0.5 \
  --restart=on-failure:3 \
  -p 127.0.0.1:8000:8000 \
  "$IMAGE"

echo "Started $NAME. Try: curl -s http://127.0.0.1:8000/health"
