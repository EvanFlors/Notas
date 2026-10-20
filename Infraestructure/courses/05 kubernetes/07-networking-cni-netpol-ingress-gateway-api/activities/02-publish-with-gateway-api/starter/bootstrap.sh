#!/usr/bin/env bash
# Bootstrap de k8s-07-02: cluster kind + CRDs Gateway API + Services placeholder.
# Deja plantillas en /tmp/k8s07-act2/manifests/.
set -eu

BASE="${1:-/tmp/k8s07-act2}"
CLUSTER="${CLUSTER:-k8s07-act2}"
GWAPI_VERSION="v1.1.0"

if ! command -v kind    >/dev/null 2>&1; then echo "SKIP: kind no instalado.";    exit 0; fi
if ! command -v kubectl >/dev/null 2>&1; then echo "SKIP: kubectl no instalado."; exit 0; fi
if ! docker info >/dev/null 2>&1;         then echo "SKIP: docker daemon no responde."; exit 0; fi

rm -rf "$BASE"
mkdir -p "$BASE/manifests"

echo "== Crear cluster kind =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
else
  echo "Cluster '$CLUSTER' ya existe, reusando."
fi
kubectl config use-context "kind-${CLUSTER}"

echo "== Instalar CRDs Gateway API ${GWAPI_VERSION} =="
kubectl apply -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GWAPI_VERSION}/standard-install.yaml"

echo "== Namespaces y Services placeholder =="
kubectl create namespace gateway-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app            --dry-run=client -o yaml | kubectl apply -f -

kubectl -n app apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: shop-web, labels: { app: shop-web } }
spec:
  replicas: 1
  selector: { matchLabels: { app: shop-web } }
  template:
    metadata: { labels: { app: shop-web } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [ { containerPort: 80 } ]
---
apiVersion: v1
kind: Service
metadata: { name: shop-web }
spec:
  selector: { app: shop-web }
  ports: [ { port: 80, targetPort: 80, name: http } ]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: shop-api, labels: { app: shop-api } }
spec:
  replicas: 1
  selector: { matchLabels: { app: shop-api } }
  template:
    metadata: { labels: { app: shop-api } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [ { containerPort: 80 } ]
---
apiVersion: v1
kind: Service
metadata: { name: shop-api }
spec:
  selector: { app: shop-api }
  ports: [ { port: 8080, targetPort: 80, name: http } ]
EOF

kubectl -n app rollout status deploy/shop-web --timeout=120s
kubectl -n app rollout status deploy/shop-api --timeout=120s

cat > "$BASE/manifests/10-gatewayclass.yaml" <<'EOF'
# TODO: GatewayClass
#   metadata.name: example
#   spec.controllerName: example.com/not-installed
# Es cluster-scoped (no lleva namespace).
EOF

cat > "$BASE/manifests/20-gateway.yaml" <<'EOF'
# TODO: Gateway en namespace gateway-system
#   metadata.name: shared
#   spec.gatewayClassName: example
#   spec.listeners:
#     - name: http
#       protocol: HTTP
#       port: 80
#       allowedRoutes:
#         namespaces:
#           from: Selector
#           selector:
#             matchLabels:
#               gateway-access: "yes"
EOF

cat > "$BASE/manifests/30-httproute.yaml" <<'EOF'
# TODO: HTTPRoute en namespace app
#   metadata.name: shop
#   spec.parentRefs:
#     - name: shared
#       namespace: gateway-system
#   spec.hostnames: ["shop.example.local"]
#   spec.rules:
#     - matches:
#         - path: { type: PathPrefix, value: /api }
#       backendRefs:
#         - name: shop-api
#           port: 8080
#       # con filtro RequestHeaderModifier que add X-Route-By: gateway-api
#       filters:
#         - type: RequestHeaderModifier
#           requestHeaderModifier:
#             add:
#               - name: X-Route-By
#                 value: gateway-api
#     - matches:
#         - path: { type: PathPrefix, value: / }
#       backendRefs:
#         - name: shop-web
#           port: 80
# RECORDA tambien:
#   kubectl label namespace app gateway-access=yes --overwrite
EOF

cat > "$BASE/NOTES.md" <<EOF
# k8s-07-02 scratch

Cluster:   kind "$CLUSTER"
CRDs:      Gateway API ${GWAPI_VERSION}
Namespaces: gateway-system, app
Services:  shop-web (app:80), shop-api (app:8080)

Edita:
  $BASE/manifests/10-gatewayclass.yaml
  $BASE/manifests/20-gateway.yaml
  $BASE/manifests/30-httproute.yaml

Etiqueta el namespace app para habilitar attach:
  kubectl label namespace app gateway-access=yes --overwrite

Aplica:
  kubectl apply -f $BASE/manifests/

Valida:
  bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/02-publish-with-gateway-api/tests/validate.sh

Limpia:
  kind delete cluster --name $CLUSTER
  rm -rf $BASE
EOF

echo "== Bootstrap OK =="
echo "Scratch:   $BASE"
echo "Manifests: $BASE/manifests/*.yaml  (edita y aplica)"
