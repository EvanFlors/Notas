#!/usr/bin/env bash
# Compare the WRONG and CORRECT Application manifests for the HPA+replicas pitfall.
# Validates both client-side and prints their meaningful diff.
#
# Note: `set -o pipefail` NOT enabled; we grep -q piped output deliberately.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
WRONG="$HERE/application-wrong.yaml"
RIGHT="$HERE/application-correct.yaml"
DEPLOY="$HERE/deployment-with-hpa.yaml"

echo "== argo-03 example 02: ignoreDifferences for HPA-managed replicas =="
echo

for f in "$WRONG" "$RIGHT" "$DEPLOY"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: missing file $f"
    exit 1
  fi
done

echo "## Underlying workload (Deployment + HPA):"
echo "   $DEPLOY"
echo

echo "## 1. Diff between WRONG and CORRECT Applications:"
diff -u "$WRONG" "$RIGHT" || true
echo

echo "## 2. Check: does the WRONG manifest have ignoreDifferences? (expect: no)"
if grep -q '^  ignoreDifferences:' "$WRONG"; then
  echo "   UNEXPECTED: $WRONG has ignoreDifferences; it should NOT for the demo."
  exit 1
else
  echo "   OK: $WRONG does NOT have ignoreDifferences — this is the pitfall."
fi
echo

echo "## 3. Check: does the CORRECT manifest ignore /spec/replicas?"
if grep -q '/spec/replicas' "$RIGHT"; then
  echo "   OK: $RIGHT ignores /spec/replicas on apps/Deployment."
else
  echo "   FAIL: $RIGHT should ignore /spec/replicas."
  exit 1
fi

echo "## 4. Check: does the CORRECT manifest use RespectIgnoreDifferences=true?"
if grep -q 'RespectIgnoreDifferences=true' "$RIGHT"; then
  echo "   OK: $RIGHT uses RespectIgnoreDifferences=true (indispensable)."
else
  echo "   FAIL: $RIGHT must include RespectIgnoreDifferences=true in syncOptions."
  exit 1
fi
echo

echo "## 5. Client-side validation of both manifests:"
if command -v kubectl >/dev/null 2>&1; then
  for f in "$WRONG" "$RIGHT" "$DEPLOY"; do
    echo "   -> $f"
    kubectl apply --dry-run=client --validate=false -f "$f" 2>&1 | sed 's/^/      /'
  done
else
  echo "   SKIP: kubectl not installed."
fi
echo

echo "== Done. =="
echo
echo "Takeaway: WITHOUT ignoreDifferences + RespectIgnoreDifferences=true,"
echo "the WRONG manifest fights the HPA on every reconcile loop."
