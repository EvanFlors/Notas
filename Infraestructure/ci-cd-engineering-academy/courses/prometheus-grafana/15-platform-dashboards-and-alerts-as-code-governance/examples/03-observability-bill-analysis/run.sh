#!/usr/bin/env bash
# Compute the monthly observability bill for the example profile.
# No `set -o pipefail` to avoid SIGPIPE issues with grep -q elsewhere.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 requerido."
  exit 2
fi

python3 bill.py profile.yaml prices.yaml
