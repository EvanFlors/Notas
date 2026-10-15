#!/usr/bin/env bash
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="/tmp/tf14-act02"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cp "$HERE/context.md"       "$WORKDIR/"
cp "$HERE/adr-template.md"  "$WORKDIR/"

echo "ready: $WORKDIR"
echo "next:  cd $WORKDIR && cp adr-template.md adr.md && \$EDITOR adr.md"
