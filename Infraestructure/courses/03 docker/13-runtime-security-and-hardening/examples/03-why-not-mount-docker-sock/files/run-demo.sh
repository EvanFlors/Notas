#!/usr/bin/env bash
# Spin up the victim container, bind-mount the demo script in, run it.
# NOTE: no `set -o pipefail` because we pipe grep -q later.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
VICTIM="dkr13-ex03-victim"
MARKER="/tmp/dkr13-ex03-PWNED"

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: dockerd no accesible. Instala/levanta Docker primero." >&2
  exit 1
fi

# Pre-clean
docker rm -f "$VICTIM" dkr13-ex03-escape >/dev/null 2>&1 || true
rm -f "$MARKER"

echo "== Starting victim container (mounts docker.sock) =="
docker run -d --name "$VICTIM" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HERE/escape-demo.sh:/escape-demo.sh:ro" \
  docker:cli sh -c "sleep 60"

echo "== Running escape-demo.sh inside victim =="
docker exec "$VICTIM" sh /escape-demo.sh

echo "== Checking from the host =="
if [ -f "$MARKER" ]; then
  ls -l "$MARKER"
  echo "   $(cat "$MARKER")"
  echo "== PWNED (as expected). This is why you NEVER mount docker.sock. =="
else
  echo "UNEXPECTED: $MARKER no se creó. Revisa logs del victim:"
  docker logs "$VICTIM"
  exit 1
fi
