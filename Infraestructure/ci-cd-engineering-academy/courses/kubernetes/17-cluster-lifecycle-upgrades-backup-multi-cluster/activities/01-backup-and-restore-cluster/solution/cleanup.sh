#!/usr/bin/env bash
# Cleanup for k8s-17-01. Removes cluster and scratch files.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-k8s-17-lab}"
WORKDIR="${WORKDIR:-/tmp/k8s-17-lab}"

kind delete cluster --name "$CLUSTER_NAME" || true
rm -rf "$WORKDIR"
echo "Cleanup done."
