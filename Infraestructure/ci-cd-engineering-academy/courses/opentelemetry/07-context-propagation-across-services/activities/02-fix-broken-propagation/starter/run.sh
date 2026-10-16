#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../tests/validate.sh"
