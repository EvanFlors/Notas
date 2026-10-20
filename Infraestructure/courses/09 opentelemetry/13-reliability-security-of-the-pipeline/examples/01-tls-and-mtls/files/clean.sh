#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${BASE_DIR:-/tmp/otel13-ex01}"
docker compose -f "$HERE/docker-compose.yaml" down -v --remove-orphans 2>/dev/null || true
rm -rf "$BASE"
echo "Limpiado $BASE y containers del compose."
