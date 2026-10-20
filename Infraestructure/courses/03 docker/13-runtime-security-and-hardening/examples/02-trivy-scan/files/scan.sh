#!/usr/bin/env bash
# Run Trivy scans on the two example images.
# If trivy is missing, SKIP cleanly (exit 0) so the example remains runnable
# in environments without the tool.
set -u

if ! command -v trivy >/dev/null 2>&1; then
  echo "SKIP: trivy no instalado. Instala con 'brew install trivy' u orden equivalente."
  exit 0
fi

echo "============================================================"
echo " 1) trivy image --severity HIGH,CRITICAL dkr13-ex02:bad"
echo "============================================================"
trivy image --severity HIGH,CRITICAL --no-progress dkr13-ex02:bad || true

echo
echo "============================================================"
echo " 2) trivy config --severity HIGH,CRITICAL Dockerfile.bad"
echo "============================================================"
trivy config --severity HIGH,CRITICAL --no-progress Dockerfile.bad || true

echo
echo "============================================================"
echo " 3) trivy image --severity HIGH,CRITICAL dkr13-ex02:good"
echo "============================================================"
trivy image --severity HIGH,CRITICAL --no-progress dkr13-ex02:good || true

echo
echo "============================================================"
echo " 4) trivy config --severity HIGH,CRITICAL Dockerfile.good"
echo "============================================================"
trivy config --severity HIGH,CRITICAL --no-progress Dockerfile.good || true

echo
echo "============================================================"
echo " 5) Gate de CI: CRITICAL con fix -> exit 1"
echo "============================================================"
if trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed --no-progress dkr13-ex02:good; then
  echo "GATE OK: sin CRITICAL con fix disponible."
else
  echo "GATE FAIL: hay CRITICAL con fix. Rebuild con base actualizada."
fi
