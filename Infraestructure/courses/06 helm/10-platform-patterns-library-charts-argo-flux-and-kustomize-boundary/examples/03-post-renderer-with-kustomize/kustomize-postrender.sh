#!/usr/bin/env bash
# Helm post-renderer wrapper around `kubectl kustomize` (or standalone
# kustomize, if present). Contract: read YAML on stdin, write YAML on stdout,
# exit 0 on success. We do NOT use `set -o pipefail` because downstream greps
# in callers can close pipes early and would mark upstream producers as
# spuriously failed; here we only chain `set -eu`.
set -eu

workdir="$(mktemp -d /tmp/helm-10-ex03-work.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# Dump Helm's rendered manifests into the working directory.
cat >"$workdir/all.yaml"

# Copy the overlay files next to the dumped manifests.
here="$(cd "$(dirname "$0")" && pwd)"
cp "$here/kustomization.yaml" "$workdir/"
cp "$here/patch.yaml"         "$workdir/"

# Prefer standalone kustomize if available, otherwise fall back to kubectl.
if command -v kustomize >/dev/null 2>&1; then
  kustomize build "$workdir"
else
  kubectl kustomize "$workdir"
fi
