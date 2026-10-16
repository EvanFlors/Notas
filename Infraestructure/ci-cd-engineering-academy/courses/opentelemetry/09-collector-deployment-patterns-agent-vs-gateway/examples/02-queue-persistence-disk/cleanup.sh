#!/usr/bin/env bash
set -eu
WORK="/tmp/otel-09-ex02"
docker rm -f backend collector telemetrygen >/dev/null 2>&1 || true
docker network rm otel09ex02 >/dev/null 2>&1 || true
rm -rf "$WORK"
echo "cleanup done."
