#!/usr/bin/env bash
set -eu
if command -v kubectl >/dev/null 2>&1; then
  kubectl -n observability delete otelcol upgradable --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf /tmp/otel-12-02
echo "Cleanup done. (Shared kind cluster 'otel-12-lab' NOT deleted; use the lab-01 teardown for that.)"
