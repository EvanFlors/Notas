#!/usr/bin/env bash
# run.sh — check and test the recording rules in rules.yml.
# NOTE: deliberately no 'set -o pipefail' because downstream greps may short-circuit a pipe.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v promtool >/dev/null 2>&1; then
  echo "SKIP: promtool not installed. Install Prometheus to run checks."
  exit 0
fi

echo "== promtool check rules =="
if promtool check rules rules.yml; then
  echo "  check: OK"
else
  echo "  check: FAIL"
  exit 1
fi

echo "== promtool test rules =="
if promtool test rules rule_test.yml; then
  echo "  tests: OK"
else
  echo "  tests: FAIL"
  exit 1
fi

echo
echo "OK: recording rules valid."
