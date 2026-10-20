#!/usr/bin/env bash
# Insecure counter-example: Docker defaults, no hardening. For comparison only.
set -eu

NAME="${NAME:-dkr13-ex01-insecure}"
IMAGE="${IMAGE:-dkr13-ex01:hardened}"
PORT="${PORT:-8001}"

docker rm -f "$NAME" >/dev/null 2>&1 || true

# Only --user is kept so the app can even start (image forces USER 10001).
# Everything else is Docker default: writable FS, default capabilities,
# no-new-privileges=false, no resource limits, port on all interfaces.
docker run -d \
  --name "$NAME" \
  -p "0.0.0.0:${PORT}:8000" \
  "$IMAGE"

echo "Started INSECURE $NAME. Do NOT use this pattern in production."
