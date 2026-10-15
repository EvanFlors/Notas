#!/usr/bin/env bash
# Starter for dkr-10-02-why-is-my-app-oomkilled.
# Runs a container with --memory=64m that tries to allocate ~128M.
# The container will be OOMKilled on purpose. The student investigates.
#
# Usage:
#   bash starter/run-broken.sh            # uses polinux/stress (requires network)
#   bash starter/run-broken.sh --fallback # uses busybox + tail /dev/zero (no stress image)

set -eu  # NO pipefail — intentional per project convention.

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  echo "SKIP: Linux required (uname -s = $OS)."
  echo "      Launch a Linux VM (multipass / vagrant) and run inside it."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker not installed." >&2; exit 1
fi

MODE="${1:-stress}"
docker rm -f oom-victim >/dev/null 2>&1 || true

case "$MODE" in
  --fallback)
    # busybox fallback: allocate memory via a bash loop in /dev/shm
    # tail of /dev/zero into /dev/shm/x will fill tmpfs (which is accounted to cgroup).
    docker run -d --name oom-victim --memory=64m --memory-swap=64m busybox:latest \
      sh -c 'dd if=/dev/zero of=/dev/shm/x bs=1M count=200; echo done'
    ;;
  *)
    docker run -d --name oom-victim --memory=64m --memory-swap=64m polinux/stress:latest \
      stress --vm 1 --vm-bytes 128M --vm-hang 0 --timeout 10
    ;;
esac

# Give it a couple of seconds to die
sleep 3

echo
echo "Container state:"
docker ps -a --filter name=oom-victim --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
echo
echo "Hint: now run:"
echo "  docker inspect oom-victim --format '{{.State.ExitCode}} {{.State.OOMKilled}}'"
echo
echo "Then write your findings to /tmp/oom-investigation/root-cause.md and run"
echo "  bash tests/validate.sh"
