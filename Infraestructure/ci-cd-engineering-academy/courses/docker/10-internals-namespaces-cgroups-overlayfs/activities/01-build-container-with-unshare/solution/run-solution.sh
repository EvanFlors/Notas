#!/usr/bin/env bash
# Reference solution for dkr-10-01-build-container-with-unshare.
# Linux-only. On non-Linux, prints SKIP and exits 0.
#
# What it does:
#   1. Exports a busybox rootfs to /tmp/mini-rootfs
#   2. Creates /sys/fs/cgroup/mini with memory.max=64MiB, pids.max=50
#   3. Launches a short-lived process in new namespaces, places it in the cgroup,
#      and intentionally OOMs it so memory.events records an oom_kill.
#   4. Captures evidence to /tmp/mini-notes/ for the validator.

set -eu  # NO pipefail (grep -q with pipes produces 141 as noted in project convention)

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  echo "SKIP: this solution requires Linux (uname -s = $OS)."
  echo "      Launch an Ubuntu VM (multipass launch 22.04 OR vagrant up ubuntu/jammy64)"
  echo "      and run this script inside the VM."
  exit 0
fi

if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
  echo "FAIL: this script needs root or sudo." >&2
  exit 1
fi
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# 0. Preconditions
if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker not installed." >&2; exit 1
fi
if ! command -v unshare >/dev/null 2>&1; then
  echo "FAIL: unshare not installed (util-linux missing)." >&2; exit 1
fi
CG_TYPE="$(stat -fc %T /sys/fs/cgroup || echo unknown)"
if [ "$CG_TYPE" != "cgroup2fs" ]; then
  echo "FAIL: /sys/fs/cgroup is '$CG_TYPE'; cgroup v2 unified hierarchy required." >&2
  exit 1
fi

ROOTFS="/tmp/mini-rootfs"
NOTES="/tmp/mini-notes"
CG="/sys/fs/cgroup/mini"

# 1. Rootfs
$SUDO rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"
CID="$(docker create busybox:latest)"
docker export "$CID" | $SUDO tar -C "$ROOTFS" -xf -
docker rm "$CID" >/dev/null

# 2. cgroup
$SUDO mkdir -p "$CG"
echo "+memory +pids +cpu" | $SUDO tee /sys/fs/cgroup/cgroup.subtree_control >/dev/null || true
echo $((64*1024*1024)) | $SUDO tee "$CG/memory.max" >/dev/null
echo 50                | $SUDO tee "$CG/pids.max"   >/dev/null

# 3. Launch an unshared short-lived child that:
#    - prints its namespace inodes
#    - gets placed in the cgroup (we do it from here using its PID)
#    - allocates 200 MiB to trigger the OOM-killer
#
# We background the unshare and capture its PID, then put the PID in cgroup.procs
# BEFORE it starts allocating memory. The child busy-waits briefly (sleep) so we
# have a window to place it. Then we signal to continue.

mkdir -p "$NOTES"
FIFO="$(mktemp -u /tmp/mini-fifo.XXXXXX)"
mkfifo "$FIFO"

$SUDO unshare --user --map-root-user --mount --uts --ipc --net --pid --fork \
             --mount-proc="$ROOTFS/proc" \
             chroot "$ROOTFS" /bin/sh -c "
  echo \$\$ > /proc/self/status.pid 2>/dev/null || true
  # Wait for the host to place us in the cgroup
  read go < $FIFO
  # Try to allocate 200 MiB; expected to be killed.
  dd if=/dev/zero of=/dev/shm/x bs=1M count=200 >/dev/null 2>&1 || true
  echo done > $FIFO
" &
UPID=$!

# Grab the real sh pid (child of the unshare). It may take a moment to appear.
sleep 0.3
PID="$(pgrep -P "$UPID" | head -1 || true)"
if [ -z "$PID" ]; then
  # Fallback: use ps + awk
  PID="$(ps -ef | awk '/chroot \/tmp\/mini-rootfs/ {print $2; exit}')"
fi
echo "Container shell host-side PID: $PID"

if [ -n "$PID" ]; then
  echo "$PID" | $SUDO tee "$CG/cgroup.procs" >/dev/null
  $SUDO readlink /proc/$PID/ns/pid /proc/$PID/ns/net /proc/$PID/ns/mnt \
                  /proc/$PID/ns/uts /proc/$PID/ns/user /proc/$PID/ns/ipc \
                  > "$NOTES/ns.txt" 2>/dev/null || true
  $SUDO lsns -p "$PID" > "$NOTES/lsns.txt" 2>/dev/null || true
fi

# Signal the child to proceed with the OOM attempt
echo go > "$FIFO" || true
# Wait for it to finish/get killed
wait "$UPID" 2>/dev/null || true
rm -f "$FIFO"

# 4. Capture evidence
$SUDO cat "$CG/memory.max"    > "$NOTES/memory.max"
$SUDO cat "$CG/pids.max"      > "$NOTES/pids.max"
$SUDO cat "$CG/memory.events" > "$NOTES/memory.events"

echo
echo "===== Evidence written to $NOTES/ ====="
ls -la "$NOTES/"
echo
echo "===== memory.events ====="
cat "$NOTES/memory.events"
echo
echo "OK: solution ran."
