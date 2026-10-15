#!/usr/bin/env bash
# Reference solution for k8s-03-02-rollout-and-rollback.
# Idempotent-ish: deletes namespace first to always get a clean history.
set -eu

NS="k8s-03-02"
NAME="rollout-demo"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no está instalado."
  exit 0
fi
if ! kubectl config current-context >/dev/null 2>&1 \
   || ! kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible."
  exit 0
fi

kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null
kubectl create namespace "$NS"

# Revision 1 — baseline.
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  namespace: $NS
  labels: { app: $NAME }
spec:
  replicas: 3
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector:
    matchLabels: { app: $NAME }
  template:
    metadata:
      labels: { app: $NAME }
    spec:
      containers:
        - name: web
          image: nginx:1.25-alpine
          ports: [{ containerPort: 80 }]
EOF
kubectl annotate -n "$NS" deployment/"$NAME" \
  kubernetes.io/change-cause="rev1: baseline nginx 1.25-alpine" --overwrite
kubectl rollout status -n "$NS" deployment/"$NAME" --timeout=300s

# Revision 2 — the one we will roll back to.
kubectl set image -n "$NS" deployment/"$NAME" web=nginx:1.26-alpine
kubectl annotate -n "$NS" deployment/"$NAME" \
  kubernetes.io/change-cause="rev2: bump to nginx 1.26-alpine" --overwrite
kubectl rollout status -n "$NS" deployment/"$NAME" --timeout=300s

# Revision 3.
kubectl set image -n "$NS" deployment/"$NAME" web=nginx:1.27-alpine
kubectl annotate -n "$NS" deployment/"$NAME" \
  kubernetes.io/change-cause="rev3: bump to nginx 1.27-alpine" --overwrite
kubectl rollout status -n "$NS" deployment/"$NAME" --timeout=300s

# Revision 4.
kubectl set image -n "$NS" deployment/"$NAME" web=nginxdemos/hello:plain-text
kubectl annotate -n "$NS" deployment/"$NAME" \
  kubernetes.io/change-cause="rev4: switch to nginxdemos/hello:plain-text" --overwrite
kubectl rollout status -n "$NS" deployment/"$NAME" --timeout=300s

echo "---- history before undo ----"
kubectl rollout history -n "$NS" deployment/"$NAME"

# Rollback to revision 2.
kubectl rollout undo -n "$NS" deployment/"$NAME" --to-revision=2
kubectl annotate -n "$NS" deployment/"$NAME" \
  kubernetes.io/change-cause="rollback to rev2 (nginx 1.26-alpine)" --overwrite
kubectl rollout status -n "$NS" deployment/"$NAME" --timeout=300s

echo "---- final state ----"
kubectl get deployment -n "$NS" "$NAME" -o wide
img="$(kubectl get deployment -n "$NS" "$NAME" -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "image = $img  (expected nginx:1.26-alpine)"
kubectl rollout history -n "$NS" deployment/"$NAME"
