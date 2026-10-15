#!/usr/bin/env bash
# Copy step1 and step2 into /tmp/tf14-ex03 for a clean working dir.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="/tmp/tf14-ex03"

rm -rf "$BASE"
mkdir -p "$BASE/data"
cp -R "$HERE/step1" "$BASE/step1"
cp -R "$HERE/step2" "$BASE/step2"

echo "ready: $BASE/{step1,step2,data}"
echo "next:  cd $BASE/step1 && terraform init && terraform apply -auto-approve"
