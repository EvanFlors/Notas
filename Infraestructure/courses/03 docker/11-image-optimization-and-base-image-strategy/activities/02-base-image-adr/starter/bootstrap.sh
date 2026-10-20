#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${1:-/tmp/dkr-11-adr}"
mkdir -p "$BASE"
cp -R "$HERE"/{app.py,requirements.txt} "$BASE/"
echo "Starter copied to $BASE"
echo "Now write your Dockerfile.slim / Dockerfile.alpine / Dockerfile.distroless there,"
echo "measure, and produce ADR-0001-base-image.md and measurements.md."
