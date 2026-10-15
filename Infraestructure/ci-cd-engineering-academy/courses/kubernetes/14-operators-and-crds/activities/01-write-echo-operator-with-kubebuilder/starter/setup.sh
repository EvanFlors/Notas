#!/usr/bin/env bash
# Decide whether the student takes path A (real Kubebuilder operator)
# or path B (documentation-only), and prepare /tmp/k8s-14-echo-operator/
# with a minimal scaffold if path A is possible.
#
# Idempotent. Safe to re-run.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRATCH="/tmp/k8s-14-echo-operator"

have() { command -v "$1" >/dev/null 2>&1; }

MODE="B"
if have go && have kubebuilder && have kubectl; then
  MODE="A"
fi

echo "== setup.sh =="
echo "Detected: go=$(have go && echo yes || echo no)  kubebuilder=$(have kubebuilder && echo yes || echo no)  kubectl=$(have kubectl && echo yes || echo no)  kind=$(have kind && echo yes || echo no)"
echo "Chosen mode: $MODE"

if [ "$MODE" = "A" ]; then
  echo
  echo "Mode A: creating scaffold under $SCRATCH"
  mkdir -p "$SCRATCH"
  # Copy the pre-made scaffold snippets so the student doesn't have to run
  # kubebuilder init from scratch. We only ship the files that need editing.
  mkdir -p "$SCRATCH/api/v1alpha1" "$SCRATCH/internal/controller" "$SCRATCH/config/samples"
  cp -f "$HERE/kubebuilder-scaffold/api/v1alpha1/echo_types.go"            "$SCRATCH/api/v1alpha1/echo_types.go"
  cp -f "$HERE/kubebuilder-scaffold/internal/controller/echo_controller.go" "$SCRATCH/internal/controller/echo_controller.go"
  cp -f "$HERE/kubebuilder-scaffold/config/samples/demo_v1alpha1_echo.yaml" "$SCRATCH/config/samples/demo_v1alpha1_echo.yaml"
  cp -f "$HERE/kubebuilder-scaffold/README-SCAFFOLD.md"                     "$SCRATCH/README-SCAFFOLD.md"
  echo
  echo "Next steps:"
  echo "  1) Read $SCRATCH/README-SCAFFOLD.md for the full flow."
  echo "  2) Edit $SCRATCH/internal/controller/echo_controller.go and complete the TODOs."
  echo "  3) Run: bash tests/validate.sh"
else
  echo
  echo "Mode B: no Go/Kubebuilder toolchain found."
  echo "You will complete starter/EVALUATION.md (CRD YAML + Reconcile pseudocode)."
  echo "That is a valid completion of this activity."
  echo
  echo "Next steps:"
  echo "  1) Edit $HERE/EVALUATION.md following the section markers."
  echo "  2) Run: bash tests/validate.sh"
fi
