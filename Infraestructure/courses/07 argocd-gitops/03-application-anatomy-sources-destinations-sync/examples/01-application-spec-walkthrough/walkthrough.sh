#!/usr/bin/env bash
# Walk through examples/01-application-spec-walkthrough/application.yaml
# field by field. Validates offline (always) and server-side if cluster + CRD exist.
#
# Note: no `set -o pipefail` because we use `grep -q` on piped kubectl output;
# pipefail would flag SIGPIPE from kubectl as a failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$HERE/application.yaml"

echo "== argo-03 example 01: Application walkthrough =="
echo "Manifest: $MANIFEST"
echo

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: $MANIFEST not found"
  exit 1
fi

print_block() {
  local title="$1"; shift
  local pattern="$1"; shift
  echo "--- $title ---"
  # Use awk to extract from pattern to next top-level key or EOF.
  awk -v pat="$pattern" '
    $0 ~ pat {inblk=1}
    inblk && NR>1 && /^[a-zA-Z]/ && $0 !~ pat {inblk=0}
    inblk {print}
  ' "$MANIFEST"
  echo
}

echo "## 1. Header (apiVersion, kind, metadata)"
sed -n '1,20p' "$MANIFEST"
echo

echo "## 2. spec.source — where manifests come from"
sed -n '/^  source:/,/^  destination:/p' "$MANIFEST" | sed '$d'
echo

echo "## 3. spec.destination — where resources go"
sed -n '/^  destination:/,/^  syncPolicy:/p' "$MANIFEST" | sed '$d'
echo

echo "## 4. spec.syncPolicy — how and when"
sed -n '/^  syncPolicy:/,/^  ignoreDifferences:/p' "$MANIFEST" | sed '$d'
echo

echo "## 5. spec.ignoreDifferences — fields owned by other controllers"
sed -n '/^  ignoreDifferences:/,/^  info:/p' "$MANIFEST" | sed '$d'
echo

echo "## 6. spec.info — operational metadata (surfaced in Argo CD UI)"
sed -n '/^  info:/,$p' "$MANIFEST"
echo

echo "== Validation =="

# 1. kubectl client-side (syntactic): always works if kubectl is installed.
#    Use --validate=false because without a reachable cluster kubectl cannot
#    fetch openapi and would fail even for pure client-side dry-run.
if command -v kubectl >/dev/null 2>&1; then
  echo "-> kubectl --dry-run=client --validate=false (syntactic parse):"
  if kubectl apply --dry-run=client --validate=false -f "$MANIFEST" 2>&1; then
    echo "   OK: client-side parse passed."
  else
    echo "   WARN: kubectl --dry-run=client reported issues (shown above)."
  fi
else
  echo "-> SKIP: kubectl not installed."
fi

echo

# 2. kubectl server-side (requires reachable cluster + Argo CD CRD).
if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
  if kubectl api-resources --api-group=argoproj.io 2>/dev/null | grep -q '^applications'; then
    echo "-> kubectl --dry-run=server (schema validation against Argo CD CRD):"
    if kubectl apply --dry-run=server -f "$MANIFEST" 2>&1; then
      echo "   OK: server-side validation passed."
    else
      echo "   WARN: server-side validation reported issues (shown above)."
    fi
  else
    echo "-> SKIP server-side validation: Argo CD CRD not installed in current cluster."
    echo "   (Install Argo CD per argo-02 module to enable this check.)"
  fi
else
  echo "-> SKIP server-side validation: no reachable cluster."
  echo "   (Create a kind cluster per argo-02 module to enable this check.)"
fi

echo

# 3. kubeconform (schema-based, no cluster needed), if available.
if command -v kubeconform >/dev/null 2>&1; then
  echo "-> kubeconform (offline schema validation):"
  # Argo CD CRD lives in a community schema; use --ignore-missing-schemas to tolerate.
  kubeconform -ignore-missing-schemas -summary "$MANIFEST" || true
else
  echo "-> SKIP kubeconform: not installed (optional)."
fi

echo
echo "== Done. =="
