#!/usr/bin/env bash
# Patrón correcto: glob + quoting + protección contra "sin matches".
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-.}"
cd "$DIR"

shopt -s nullglob dotglob

count=0
echo "=== GOOD: for f in * (con nullglob) ==="
for f in *; do
  echo "  f = [$f]"
  count=$((count + 1))
done
echo "total iteraciones: $count"
