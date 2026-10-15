#!/usr/bin/env bash
# Reference solution for dkr-10-02-why-is-my-app-oomkilled.
# Reproduces, investigates and writes evidence that passes the validator.

set -eu  # NO pipefail

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  echo "SKIP: Linux required (uname -s = $OS)."
  exit 0
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$HERE/.." && pwd)"

# 1. Reproduce the broken container
bash "$ACT_DIR/starter/run-broken.sh" --fallback

# 2. Investigation outputs
OUT="/tmp/oom-investigation"
mkdir -p "$OUT"
docker inspect oom-victim > "$OUT/inspect.json"

ID="$(docker inspect oom-victim --format '{{.Id}}')"
CG_SYSTEMD="/sys/fs/cgroup/system.slice/docker-$ID.scope"
CG_CGFS="/sys/fs/cgroup/docker/$ID"
if [ -d "$CG_SYSTEMD" ]; then
  CG="$CG_SYSTEMD"
elif [ -d "$CG_CGFS" ]; then
  CG="$CG_CGFS"
else
  CG=""
fi
if [ -n "$CG" ] && [ -r "$CG/memory.events" ]; then
  sudo cat "$CG/memory.events" > "$OUT/memory.events" 2>/dev/null \
    || cat "$CG/memory.events" > "$OUT/memory.events" 2>/dev/null || true
fi

# 3. Write the root-cause note that satisfies the validator
cp "$HERE/root-cause.md" "$OUT/root-cause.md"

echo
echo "Evidence in $OUT/:"
ls -la "$OUT"
echo
echo "Run: bash tests/validate.sh"
