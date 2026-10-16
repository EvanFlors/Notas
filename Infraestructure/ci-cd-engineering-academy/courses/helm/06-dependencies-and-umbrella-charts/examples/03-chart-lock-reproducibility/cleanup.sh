#!/usr/bin/env bash
set -euo pipefail
WORK="${1:-/tmp/helm-ex-03}"
rm -rf "$WORK"
echo "Removed $WORK"
