#!/usr/bin/env bash
# Measure cold vs warm rebuild for the cache-friendly Dockerfile.
# Note: no `set -o pipefail` — we use `grep -q` on docker output and don't want
# SIGPIPE to spuriously mark success as failure.
set -eu

IMG="cache-demo:latest"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

echo "== Cold build (clearing cache for this image) =="
docker rmi "$IMG" >/dev/null 2>&1 || true
docker builder prune -af --filter "label=cache-demo=ephemeral" >/dev/null 2>&1 || true
time docker build --no-cache -t "$IMG" .

echo
echo "== Warm rebuild after touching app.py (should reuse pip install) =="
# Touch app.py to simulate a code change (append + remove a newline).
printf '\n' >> app.py
time docker build -t "$IMG" .
# Revert the touch so the file is clean.
# Portable 1-line truncation: rewrite without the trailing blank line.
python3 - <<'PY'
from pathlib import Path
p = Path("app.py")
text = p.read_text()
if text.endswith("\n\n"):
    p.write_text(text[:-1])
PY

echo
echo "== Verifying pip install was cached =="
if docker build --progress=plain -t "$IMG" . 2>&1 | grep -E "CACHED .*pip install" >/dev/null; then
  echo "OK: pip install was served from cache."
else
  echo "WARN: could not confirm cache hit on pip install — review the output above."
fi
