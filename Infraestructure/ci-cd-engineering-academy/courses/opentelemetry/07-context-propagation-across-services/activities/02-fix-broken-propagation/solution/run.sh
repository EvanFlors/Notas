#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HERE" exec bash "$HERE/../tests/validate.sh"
