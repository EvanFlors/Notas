#!/usr/bin/env bash
# Teardown for otel-12-01.
set -eu
CLUSTER="otel-12-lab"
STAGE="/tmp/otel-12-lab"

if command -v kind >/dev/null 2>&1; then
  kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
fi
rm -rf "$STAGE"
echo "Cleanup done."
