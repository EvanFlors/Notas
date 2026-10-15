#!/usr/bin/env bash
# Prepare a clean scratch dir for gh-04-01-local-bare-remote.
# This activity is deliberately "build from scratch": the starter does NOT
# create the bare repo or the clone — YOU do that following README steps.
set -euo pipefail

BASE="${1:-/tmp/gh-04-bare}"
rm -rf "$BASE"
mkdir -p "$BASE"

echo "Scratch dir listo en: $BASE"
echo
echo "Siguiente paso (según README.md):"
echo "  cd $BASE"
echo "  git init --bare -b main origin.git"
echo "  (y continúa con los pasos 2–9)"
