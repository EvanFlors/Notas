#!/usr/bin/env bash
# Hardened docker run with the six production controls.
set -eu

NAME="${NAME:-dkr13-ex01-hardened}"
IMAGE="${IMAGE:-dkr13-ex01:hardened}"
PORT="${PORT:-8000}"

docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$NAME" \
  --user 10001:10001 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --memory=128m \
  --memory-swap=128m \
  --pids-limit=50 \
  --cpus=0.5 \
  --restart=on-failure:3 \
  -p "127.0.0.1:${PORT}:8000" \
  "$IMAGE"

echo "Started $NAME. Try: curl -s http://127.0.0.1:${PORT}/"
