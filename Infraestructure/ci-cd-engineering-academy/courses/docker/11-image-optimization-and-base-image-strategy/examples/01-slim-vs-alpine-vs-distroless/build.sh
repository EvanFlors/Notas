#!/usr/bin/env bash
# Build the same app on three base images, print size + a runtime check,
# then clean up. SKIP gracefully if docker is missing.
#
# Deliberately NO `set -o pipefail`: we pipe `docker images` through grep -q,
# which can produce SIGPIPE on the producer and poison the exit code.
set -eu

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

echo "== build.sh =="

build_one() {
  local tag="$1" file="$2"
  echo "building $tag ..."
  docker build -q -t "$tag" -f "$file" . >/dev/null
  echo "  built $tag"
}

build_one "app:slim"       "Dockerfile.slim"
build_one "app:alpine"     "Dockerfile.alpine"
build_one "app:distroless" "Dockerfile.distroless"

echo
echo "TAG                  SIZE"
docker images --format "{{.Repository}}:{{.Tag}}  {{.Size}}" \
  | grep -E '^app:(slim|alpine|distroless) ' \
  | sort

echo
echo "runtime check:"
for tag in app:slim app:alpine app:distroless; do
  out="$(docker run --rm "$tag" 2>&1 || true)"
  echo "---- $tag ----"
  echo "$out"
done

echo
echo "cleanup: docker rmi app:slim app:alpine app:distroless"
docker rmi app:slim app:alpine app:distroless >/dev/null 2>&1 || true
echo "done."
