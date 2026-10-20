#!/usr/bin/env bash
# regenerate-fixture.sh — regenerate (or --check) the reference fixture
# of the template.
#
# Usage:
#   ./scripts/regenerate-fixture.sh           # regenerate fixture/ in place
#   ./scripts/regenerate-fixture.sh --check   # fail (exit 1) if fixture drifted
#
# If cookiecutter is not installed, exits 0 with SKIP (graceful degradation).
#
# Note: we deliberately do NOT enable `set -o pipefail` because some pipelines
# below (grep piping to head, etc.) short-circuit and produce SIGPIPE (141)
# which pipefail would misread as failure.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_JSON="$ROOT/cookiecutter.json"
CC_SKEL="$ROOT/cookiecutter-skeleton"
FIXTURE="$ROOT/fixture"

MODE="${1:-regenerate}"

if ! command -v cookiecutter >/dev/null 2>&1; then
  echo "SKIP: cookiecutter not installed; cannot regenerate/check fixture."
  echo "      Install with: pip install cookiecutter"
  exit 0
fi

if [ ! -f "$CC_JSON" ] || [ ! -d "$CC_SKEL" ]; then
  echo "ERROR: missing cookiecutter.json or cookiecutter-skeleton/ in $ROOT"
  exit 2
fi

STAGE="$(mktemp -d)"
OUT="$(mktemp -d)"
cleanup() { rm -rf "$STAGE" "$OUT"; }
trap cleanup EXIT

cp "$CC_JSON" "$STAGE/"
cp -R "$CC_SKEL"/. "$STAGE/"

cookiecutter --no-input -o "$OUT" "$STAGE" >/dev/null

RENDERED_DIR="$(find "$OUT" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [ -z "$RENDERED_DIR" ]; then
  echo "ERROR: cookiecutter produced no output directory under $OUT"
  exit 2
fi

case "$MODE" in
  --check)
    if [ ! -d "$FIXTURE" ]; then
      echo "FAIL: fixture/ does not exist. Run without --check to seed it."
      exit 1
    fi
    if diff -r "$FIXTURE" "$RENDERED_DIR" >/dev/null 2>&1; then
      echo "OK: fixture matches current skeleton render."
      exit 0
    else
      echo "FAIL: fixture drift detected."
      diff -r "$FIXTURE" "$RENDERED_DIR" || true
      echo
      echo "Run './scripts/regenerate-fixture.sh' to update."
      exit 1
    fi
    ;;
  regenerate|"")
    rm -rf "$FIXTURE"
    mkdir -p "$FIXTURE"
    cp -R "$RENDERED_DIR"/. "$FIXTURE/"
    echo "OK: fixture regenerated at $FIXTURE"
    ;;
  *)
    echo "Usage: $0 [--check]" >&2
    exit 2
    ;;
esac
