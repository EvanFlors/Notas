#!/usr/bin/env bash
# Smoke script for example 03. Compares plain Helm render against Helm +
# Kustomize post-renderer. No `set -o pipefail` on purpose — grep -q can
# close pipes early and false-positive upstream failures.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"
chmod +x kustomize-postrender.sh

echo "== 1. Plain helm template =="
plain=$(helm template demo ./my-chart)
if printf '%s\n' "$plain" | grep -q 'log-shipper'; then
  echo "  FAIL plain render should not contain sidecar 'log-shipper'"
  exit 1
else
  echo "  OK   plain render does not contain the sidecar"
fi
if printf '%s\n' "$plain" | grep -q 'corp.example.com/managed'; then
  echo "  FAIL plain render should not contain the corporate label"
  exit 1
else
  echo "  OK   plain render does not contain the corporate label"
fi

echo
echo "== 2. helm template | kustomize-postrender.sh =="
# Pipe pattern: identical semantics to `--post-renderer`, works on Helm 3 & 4.
rendered=$(helm template demo ./my-chart | "$here/kustomize-postrender.sh")
if printf '%s\n' "$rendered" | grep -q 'log-shipper'; then
  echo "  OK   post-renderer injected the sidecar"
else
  echo "  FAIL post-renderer did not inject the sidecar"
  echo "----- rendered output -----"
  printf '%s\n' "$rendered"
  exit 1
fi
if printf '%s\n' "$rendered" | grep -q 'corp.example.com/managed: "true"'; then
  echo "  OK   post-renderer added the corporate label"
else
  echo "  FAIL post-renderer did not add the corporate label"
  exit 1
fi

echo
echo "OK: example 03 smoke passed."
