#!/usr/bin/env bash
# Remove everything created by setup.sh. Safe to re-run.
set -eu

rm -rf /tmp/registry
rm -rf /tmp/consumer-tf14-01
rm -rf /tmp/greeter-out

echo "cleaned: /tmp/registry, /tmp/consumer-tf14-01, /tmp/greeter-out"
