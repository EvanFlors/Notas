#!/usr/bin/env bash
# Run the solution against the validator.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HERE" exec bash "$HERE/../tests/validate.sh"
