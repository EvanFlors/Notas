#!/usr/bin/env bash
# Reference solution for k8s-13-01. Runs the full happy path end-to-end.
# Does NOT clean up — the student runs the teardown themselves.
set -eu

CLUSTER="${CLUSTER:-k8s-13-01}"
CTX="kind-$CLUSTER"
BASE_DIR="${BASE_DIR:-/tmp/k8s-13-01}"

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter"
TESTS="$HERE/../tests"

echo "== Stage 1: ensure base dir and starter files =="
mkdir -p "$BASE_DIR"
cp -r "$STARTER"/* "$BASE_DIR"/
cd "$BASE_DIR"

echo "== Stage 2: kind cluster =="
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "cluster $CLUSTER already exists; reusing"
else
  kind create cluster --name "$CLUSTER" --config kind-config.yaml
fi

kubectl --context "$CTX" cluster-info

echo "== Stage 3: metrics-server =="
kubectl --context "$CTX" apply \
  -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Idempotent patch: only add --kubelet-insecure-tls if not already present.
if ! kubectl --context "$CTX" -n kube-system get deploy metrics-server \
       -o jsonpath='{.spec.template.spec.containers[0].args}' \
     | grep -q 'kubelet-insecure-tls'; then
  kubectl --context "$CTX" patch -n kube-system deploy metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

kubectl --context "$CTX" -n kube-system rollout status deploy metrics-server --timeout=180s

echo "== Stage 4: wait until kubectl top responds =="
for i in $(seq 1 24); do
  if kubectl --context "$CTX" top nodes >/dev/null 2>&1; then
    echo "metrics-server serving."
    break
  fi
  sleep 5
done

echo "== Stage 5: workload and HPA =="
kubectl --context "$CTX" apply -f workload.yaml
kubectl --context "$CTX" apply -f hpa.yaml
kubectl --context "$CTX" -n default rollout status deploy web --timeout=120s

echo "== Stage 6: background load generator =="
# Kill any previous load pod from a prior run.
kubectl --context "$CTX" -n default delete pod load --ignore-not-found --wait=false
kubectl --context "$CTX" -n default run load \
  --image=busybox:1.36 --restart=Never \
  --command -- sh -c 'while true; do wget -q -O- http://web.default.svc.cluster.local/ >/dev/null 2>&1; done'

echo "== Stage 7: wait for HPA to scale (up to 4 min) =="
scaled=0
for i in $(seq 1 48); do
  current="$(kubectl --context "$CTX" -n default get hpa web \
              -o jsonpath='{.status.currentReplicas}' 2>/dev/null)"
  current="${current:-0}"
  echo "  tick $i: currentReplicas=$current"
  if [ "$current" -gt 1 ] 2>/dev/null; then
    scaled=1
    break
  fi
  sleep 5
done

echo "== Stage 8: describe HPA =="
kubectl --context "$CTX" -n default describe hpa web || true

echo "== Stage 9: run validator =="
bash "$TESTS/validate.sh"

if [ "$scaled" -eq 1 ]; then
  echo "SOLUTION COMPLETE. Load pod 'load' is still running — delete it when done:"
  echo "  kubectl --context $CTX -n default delete pod load --now"
else
  echo "WARNING: HPA did not scale within the wait window. Inspect 'describe hpa web' output above."
fi
