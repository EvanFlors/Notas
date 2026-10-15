#!/usr/bin/env bash
# Reference run: materialize the solution ADR into the student workdir.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ACTIVITY_DIR="$(cd "$HERE/.." && pwd)"

bash "$ACTIVITY_DIR/starter/bootstrap.sh"
cp "$HERE/adr.md" "/tmp/tf14-act02/adr.md"
echo "solution ADR placed at /tmp/tf14-act02/adr.md"
