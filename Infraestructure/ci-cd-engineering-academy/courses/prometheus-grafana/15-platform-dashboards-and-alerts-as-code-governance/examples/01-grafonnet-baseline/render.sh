#!/usr/bin/env bash
# Render all dashboards in dashboards/ to out/ using jsonnet, then validate JSON.
# No `set -o pipefail` because downstream grep -q with pipelines can trigger SIGPIPE.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v jsonnet >/dev/null 2>&1; then
  echo "ERROR: jsonnet no está instalado. brew install jsonnet (o descarga de github.com/google/jsonnet)."
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 requerido para validar JSON."
  exit 2
fi

OUT="/tmp/obs15-ex01-out"
rm -rf "$OUT"
mkdir -p "$OUT"

rendered=0
for src in dashboards/*.jsonnet; do
  name="$(basename "${src%.jsonnet}")"
  dest="$OUT/${name}.json"
  echo "-> rendering $src -> $dest"
  jsonnet "$src" > "$dest"
  python3 -m json.tool "$dest" > /dev/null
  rendered=$((rendered + 1))
done

echo
echo "OK — all dashboards rendered and valid JSON ($rendered file(s)) in $OUT"
echo "Limpieza: rm -rf $OUT"
