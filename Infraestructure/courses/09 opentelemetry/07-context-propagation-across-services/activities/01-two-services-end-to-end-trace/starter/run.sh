#!/usr/bin/env bash
# Convenience: run service_b in background and service_a once.
# For automated validation use tests/validate.sh.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8810}" exec bash "$HERE/../tests/validate.sh"
