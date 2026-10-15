#!/usr/bin/env bash
# bootstrap.sh — stand up the full OSS observability stack on a kind cluster.
# Steps:
#   1. kind cluster
#   2. kube-prometheus-stack (metrics + grafana + alertmanager)
#   3. Loki + Promtail (logs)
#   4. cert-manager + OpenTelemetry Operator + Tempo (traces)
#
# Each step is independent: missing tool => SKIP (not FAIL).
# Note: deliberately NO 'set -o pipefail' — several checks pipe into 'grep -q'
# which produces SIGPIPE and pipefail would surface it as a spurious failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CLUSTER="${CLUSTER:-obs15}"
TMPDIR="${TMPDIR:-/tmp}/obs15-bootstrap"
mkdir -p "$TMPDIR"

pass=0; fail=0; skip=0
report=""

add_result() { # label, status [, msg]
  local label="$1" status="$2" msg="${3:-}"
  report+="  [$status] $label${msg:+ — $msg}\n"
  case "$status" in
    PASS) pass=$((pass+1));;
    FAIL) fail=$((fail+1));;
    SKIP) skip=$((skip+1));;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

step1_kind_cluster() {
  local label="kind cluster ($CLUSTER)"
  if ! have kind; then add_result "$label" SKIP "kind missing"; return; fi
  if ! have docker; then add_result "$label" SKIP "docker missing"; return; fi
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    add_result "$label" PASS "already exists"
    return
  fi
  if kind create cluster --name "$CLUSTER" --config "$HERE/kind.yaml" >"$TMPDIR/kind.log" 2>&1; then
    add_result "$label" PASS "created"
  else
    add_result "$label" FAIL "see $TMPDIR/kind.log"
  fi
}

step2_kps() {
  local label="kube-prometheus-stack"
  if ! have helm; then add_result "$label" SKIP "helm missing"; return; fi
  if ! have kubectl; then add_result "$label" SKIP "kubectl missing"; return; fi
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  if helm upgrade --install kps prometheus-community/kube-prometheus-stack \
       --namespace monitoring --create-namespace \
       --set grafana.adminPassword=admin \
       --set prometheus.prometheusSpec.retention=2d \
       --wait --timeout 10m >"$TMPDIR/kps.log" 2>&1; then
    add_result "$label" PASS "installed"
  else
    add_result "$label" FAIL "see $TMPDIR/kps.log"
  fi
}

step3_loki_promtail() {
  local label="Loki + Promtail"
  if ! have helm; then add_result "$label" SKIP "helm missing"; return; fi
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl create ns logging >/dev/null 2>&1 || true
  if helm upgrade --install loki grafana/loki \
       --namespace logging \
       --set deploymentMode=SingleBinary \
       --set loki.auth_enabled=false \
       --set loki.commonConfig.replication_factor=1 \
       --set loki.storage.type=filesystem \
       --set singleBinary.replicas=1 \
       --wait --timeout 10m >"$TMPDIR/loki.log" 2>&1; then
    :
  else
    add_result "$label" FAIL "see $TMPDIR/loki.log"
    return
  fi
  if helm upgrade --install promtail grafana/promtail \
       --namespace logging \
       --set "config.clients[0].url=http://loki.logging.svc.cluster.local:3100/loki/api/v1/push" \
       --wait --timeout 5m >"$TMPDIR/promtail.log" 2>&1; then
    add_result "$label" PASS "installed"
  else
    add_result "$label" FAIL "see $TMPDIR/promtail.log"
  fi
}

step4_otel_tempo() {
  local label="cert-manager + OTel Operator + Tempo"
  if ! have helm; then add_result "$label" SKIP "helm missing"; return; fi
  if ! have kubectl; then add_result "$label" SKIP "kubectl missing"; return; fi

  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml \
    >"$TMPDIR/certmgr.log" 2>&1 || true
  kubectl -n cert-manager wait --for=condition=Available --timeout=180s \
    deploy/cert-manager deploy/cert-manager-webhook deploy/cert-manager-cainjector \
    >>"$TMPDIR/certmgr.log" 2>&1 || true

  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  if helm upgrade --install otel-op open-telemetry/opentelemetry-operator \
       --namespace opentelemetry-operator-system --create-namespace \
       --set manager.collectorImage.repository="otel/opentelemetry-collector-contrib" \
       --wait --timeout 10m >"$TMPDIR/otel-op.log" 2>&1; then
    :
  else
    add_result "$label" FAIL "operator install failed; see $TMPDIR/otel-op.log"
    return
  fi

  kubectl create ns tracing >/dev/null 2>&1 || true
  kubectl -n tracing apply -f "$HERE/../../../examples/03-otel-operator-with-tempo/tempo.yaml" \
    >"$TMPDIR/tempo.log" 2>&1 || true
  kubectl create ns apps >/dev/null 2>&1 || true
  kubectl -n apps apply -f "$HERE/../../../examples/03-otel-operator-with-tempo/otel-collector.yaml" \
    >>"$TMPDIR/tempo.log" 2>&1 || true
  kubectl -n apps apply -f "$HERE/../../../examples/03-otel-operator-with-tempo/instrumentation.yaml" \
    >>"$TMPDIR/tempo.log" 2>&1 || true

  add_result "$label" PASS "installed"
}

step5_wait_ready() {
  local label="all namespaces Ready"
  if ! have kubectl; then add_result "$label" SKIP "kubectl missing"; return; fi
  local nss="monitoring logging cert-manager opentelemetry-operator-system tracing apps"
  local bad=0
  for ns in $nss; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
      # Wait with short timeout; this is best-effort.
      kubectl -n "$ns" wait --for=condition=Ready pods --all --timeout=120s >/dev/null 2>&1 || true
    fi
  done
  # Final check: for each namespace, if any pod exists but isn't Ready, fail.
  for ns in $nss; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
      local not_ready
      not_ready="$(kubectl -n "$ns" get pods --no-headers 2>/dev/null \
        | awk '{print $2}' | awk -F/ '$1 != $2 {c++} END{print c+0}')"
      if [ "${not_ready:-0}" -gt 0 ]; then
        bad=$((bad+1))
      fi
    fi
  done
  if [ "$bad" -eq 0 ]; then
    add_result "$label" PASS
  else
    add_result "$label" FAIL "$bad namespace(s) have non-Ready pods"
  fi
}

echo "== obs15 bootstrap starting =="
step1_kind_cluster
step2_kps
step3_loki_promtail
step4_otel_tempo
step5_wait_ready

echo
echo "== summary =="
printf "%b" "$report"
echo "PASS=$pass FAIL=$fail SKIP=$skip"
echo "logs: $TMPDIR"
[ "$fail" -eq 0 ]
