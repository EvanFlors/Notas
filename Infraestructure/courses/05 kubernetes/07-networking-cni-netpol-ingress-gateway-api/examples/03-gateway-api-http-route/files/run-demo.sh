#!/usr/bin/env bash
# Demo: Gateway API (CRDs + GatewayClass/Gateway/HTTPRoute) en kind.
# Modo ligero (default): instala solo CRDs y manifiestos de ejemplo.
# Modo completo (WITH_CONTROLLER=1): instala Envoy Gateway via Helm.
#
# NOTA: no `set -o pipefail` por el patron `... | grep -q ...`.
set -eu

CLUSTER="k8s07-gwapi"
GWAPI_VERSION="v1.1.0"
WITH_CONTROLLER="${WITH_CONTROLLER:-0}"

if ! command -v kind >/dev/null 2>&1; then
  echo "SKIP: kind no instalado."
  exit 0
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

echo "== 0. Crear cluster kind =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
else
  echo "Cluster '$CLUSTER' ya existe, reusando."
fi

kubectl config use-context "kind-${CLUSTER}"

echo
echo "== 1. Instalar CRDs Gateway API ${GWAPI_VERSION} (standard channel) =="
kubectl apply -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GWAPI_VERSION}/standard-install.yaml"

echo
echo "== 2. Verificar CRDs presentes =="
for crd in gatewayclasses.gateway.networking.k8s.io \
           gateways.gateway.networking.k8s.io \
           httproutes.gateway.networking.k8s.io; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    echo "  OK   $crd"
  else
    echo "  FAIL $crd"
  fi
done

echo
echo "== 3. Namespaces =="
kubectl create namespace gateway-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app            --dry-run=client -o yaml | kubectl apply -f -

echo
echo "== 4. App backend =="
kubectl -n app apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, labels: { app: web } }
spec:
  replicas: 1
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [ { containerPort: 80 } ]
---
apiVersion: v1
kind: Service
metadata: { name: web }
spec:
  selector: { app: web }
  ports: [ { port: 80, targetPort: 80, name: http } ]
EOF
kubectl -n app rollout status deploy/web --timeout=120s

if [ "$WITH_CONTROLLER" = "1" ]; then
  if ! command -v helm >/dev/null 2>&1; then
    echo "SKIP controller: helm no instalado."
    WITH_CONTROLLER=0
  fi
fi

if [ "$WITH_CONTROLLER" = "1" ]; then
  echo
  echo "== 5a. Instalar Envoy Gateway (controller real) =="
  helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
    --version v1.1.2 -n envoy-gateway-system --create-namespace
  kubectl wait --namespace envoy-gateway-system \
    --for=condition=ready pod \
    --selector=control-plane=envoy-gateway \
    --timeout=180s
  GW_CTRL="gateway.envoyproxy.io/gatewayclass-controller"
else
  echo
  echo "== 5b. Modo ligero: GatewayClass apunta a controller 'example/not-installed' =="
  GW_CTRL="example.com/not-installed"
fi

echo
echo "== 6. Aplicar GatewayClass / Gateway / HTTPRoute =="
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example
spec:
  controllerName: ${GW_CTRL}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
  namespace: gateway-system
spec:
  gatewayClassName: example
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
  namespace: app
spec:
  parentRefs:
    - name: eg
      namespace: gateway-system
  hostnames:
    - "app.example.local"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 80
EOF

echo
echo "== 7. Status =="
kubectl get gatewayclass example -o yaml | grep -A4 '^status:' || true
echo
kubectl -n gateway-system describe gateway eg | sed -n '/Status:/,$p' || true
echo
kubectl -n app describe httproute web | sed -n '/Status:/,$p' || true

echo
echo "============================================================"
echo "Modo: WITH_CONTROLLER=${WITH_CONTROLLER}"
if [ "$WITH_CONTROLLER" = "1" ]; then
  echo "Envoy Gateway esta activo. kubectl -n envoy-gateway-system get svc"
else
  echo "Modo ligero: sin controller real. El HTTPRoute no vera trafico."
  echo "Reejecuta con  WITH_CONTROLLER=1  para traffic real (requiere helm)."
fi
echo "Borrar:  kind delete cluster --name $CLUSTER"
echo "============================================================"
