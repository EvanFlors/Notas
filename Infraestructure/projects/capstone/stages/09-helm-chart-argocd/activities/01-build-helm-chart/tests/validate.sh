#!/usr/bin/env bash
# Validate cap-09-01-build-helm-chart.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# `helm template` into `grep -q`; if grep matches early, the upstream helm
# process may receive SIGPIPE (exit 141) and pipefail would turn that into
# a false failure.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CHART_DIR="${STAGE_DIR}/charts/fastapi-app"
WORK="${WORK_DIR:-/tmp/cap-09-01}"

fail=0

ok()  { echo "  OK   $1"; }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }

# ---- Preflight ----
if ! command -v helm >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'helm' no esta instalado. Instala con:
  - macOS Homebrew:  brew install helm
  - script oficial:  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  - asdf:            asdf plugin add helm && asdf install helm latest
Luego: helm version   (requiere v3.14+)
EOF
  exit 0
fi

echo "== Chart layout =="
for f in Chart.yaml values.yaml values.schema.json .helmignore \
         templates/_helpers.tpl templates/deployment.yaml templates/service.yaml \
         templates/configmap.yaml templates/secret.yaml templates/serviceaccount.yaml \
         templates/ingress.yaml templates/hpa.yaml templates/NOTES.txt \
         templates/tests/test-connection.yaml; do
  if [ -f "${CHART_DIR}/${f}" ]; then ok "exists ${f}"; else bad "missing ${f}"; fi
done

echo
echo "== helm lint =="
if helm lint "${CHART_DIR}" >/tmp/cap-09-01-lint.log 2>&1; then
  ok "helm lint passed"
else
  bad "helm lint failed (see /tmp/cap-09-01-lint.log)"
fi

echo
echo "== helm template (defaults) =="
rm -rf "${WORK}" && mkdir -p "${WORK}"
if helm template fastapi "${CHART_DIR}" \
     --namespace fastapi-dev \
     --output-dir "${WORK}" >/tmp/cap-09-01-tpl.log 2>&1; then
  ok "helm template rendered"
else
  bad "helm template failed (see /tmp/cap-09-01-tpl.log)"
fi

echo
echo "== rendered manifests contain required kinds =="
RENDERED_DIR="${WORK}/fastapi-app/templates"
for kind_file in deployment.yaml service.yaml configmap.yaml secret.yaml serviceaccount.yaml; do
  if [ -f "${RENDERED_DIR}/${kind_file}" ]; then
    ok "rendered ${kind_file}"
  else
    bad "no se rendereo ${kind_file}"
  fi
done

echo
echo "== values.schema.json rejects invalid replicaCount =="
BAD="${WORK}/bad.yaml"
printf 'replicaCount: "dos"\n' > "${BAD}"
if helm template fastapi "${CHART_DIR}" \
     --values "${CHART_DIR}/values.yaml" \
     --values "${BAD}" >/dev/null 2>&1; then
  bad "schema NO rechazo replicaCount string"
else
  ok "schema rechazo replicaCount string (comportamiento esperado)"
fi

echo
echo "== helpers used (labels/selectorLabels) =="
if grep -q 'app.kubernetes.io/name' "${RENDERED_DIR}/deployment.yaml" 2>/dev/null; then
  ok "labels recomendadas presentes en deployment"
else
  bad "labels recomendadas ausentes en deployment"
fi

echo
echo "== securityContext hardening =="
if grep -q 'runAsNonRoot: true' "${RENDERED_DIR}/deployment.yaml" \
   && grep -q 'readOnlyRootFilesystem: true' "${RENDERED_DIR}/deployment.yaml"; then
  ok "securityContext hardened (runAsNonRoot + readOnlyRootFilesystem)"
else
  bad "securityContext NO esta hardened"
fi

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Chart valido y renderizable."
exit 0
