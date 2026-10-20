#!/usr/bin/env bash
# Validate cap-08-02-eks-tf-plan-walkthrough.
#
# NOTE: deliberately NO `set -o pipefail`. Grep en pipelines con
# pipefail reportaria SIGPIPE (141) espurio cuando grep sale pronto.
set -eu

STAGE_DIR="${STAGE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
ACT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

note_ok()   { echo "  OK   -- $1"; }
note_fail() { echo "  FAIL -- $1"; fail=$((fail+1)); }

echo "== Validating cap-08-02-eks-tf-plan-walkthrough =="

if command -v terraform >/dev/null 2>&1; then
  for cloud in aws/eks gcp/gke azure/aks; do
    dir="$STAGE_DIR/terraform/$cloud"
    (
      cd "$dir"
      terraform init -backend=false -input=false -no-color >/dev/null 2>&1
      terraform validate -no-color >/dev/null 2>&1
    ) && note_ok "terraform init+validate $cloud" || note_fail "terraform init+validate $cloud"
  done
else
  echo "  SKIP -- terraform no instalado; validacion de HCL omitida"
fi

if [ -f "$ACT_DIR/WALKTHROUGH.md" ]; then
  note_ok "WALKTHROUGH.md presente"
else
  echo "  WARN -- WALKTHROUGH.md ausente (entregable del estudiante)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s)."
exit 0
