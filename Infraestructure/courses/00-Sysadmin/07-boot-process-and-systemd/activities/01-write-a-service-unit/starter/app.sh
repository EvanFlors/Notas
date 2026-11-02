#!/usr/bin/env bash
# Starter: loop infinito que loguea a stdout. Lo envolveremos en un .service.
set -euo pipefail

INTERVAL="${APP_INTERVAL_SEC:-2}"
echo "sys07-app: starting, pid=$$ interval=${INTERVAL}s"

trap 'echo "sys07-app: SIGTERM received, exiting"; exit 0' TERM
trap 'echo "sys07-app: SIGINT received, exiting"; exit 0' INT

count=0
while true; do
  count=$((count + 1))
  echo "sys07-app: tick #${count} at $(date -Is)"
  sleep "${INTERVAL}"
done
