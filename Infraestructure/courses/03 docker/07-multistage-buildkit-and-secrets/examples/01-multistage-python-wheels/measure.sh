#!/usr/bin/env bash
# Build the multi-stage image and compare the final size against a monolithic
# baseline built from the same requirements. Shows why multi-stage matters.
#
# Note: no `set -o pipefail` on purpose — we pipe into `grep -q` elsewhere in
# this course and SIGPIPE on the producer would spuriously flip success to
# failure. See the pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

MULTI_IMG="multistage-demo:multi"
MONO_IMG="multistage-demo:mono"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

echo "== Building multi-stage image (final = slim, no toolchain) =="
docker build -t "$MULTI_IMG" .

echo
echo "== Building a monolithic baseline for comparison =="
TMP="$(mktemp -d)"
cp Dockerfile "$TMP/Dockerfile.multi"
cp app.py requirements.txt "$TMP/"
cat > "$TMP/Dockerfile" <<'DOCKER'
# syntax=docker/dockerfile:1
FROM python:3.12
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
DOCKER
(cd "$TMP" && docker build -t "$MONO_IMG" .)
rm -rf "$TMP"

echo
echo "== Sizes =="
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' \
  | grep -E "^REPOSITORY|multistage-demo"

echo
echo "== Checking the runtime image has NO gcc =="
if docker run --rm "$MULTI_IMG" sh -c "command -v gcc" 2>/dev/null; then
  echo "WARN: gcc found in the multi-stage runtime image. This is a bug."
else
  echo "OK: no gcc in the multi-stage runtime image."
fi
