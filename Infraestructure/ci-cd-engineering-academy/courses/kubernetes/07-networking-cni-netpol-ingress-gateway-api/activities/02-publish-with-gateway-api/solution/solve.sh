#!/usr/bin/env bash
# Solucion de referencia para k8s-07-02.
set -eu

BASE="${1:-/tmp/k8s07-act2}"
CLUSTER="${CLUSTER:-k8s07-act2}"

if ! command -v kind    >/dev/null 2>&1; then echo "SKIP: kind no instalado.";    exit 0; fi
if ! command -v kubectl >/dev/null 2>&1; then echo "SKIP: kubectl no instalado."; exit 0; fi
if ! docker info >/dev/null 2>&1;         then echo "SKIP: docker daemon no responde."; exit 0; fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
bash "$HERE/starter/bootstrap.sh" "$BASE"
kubectl config use-context "kind-${CLUSTER}" >/dev/null

kubectl label namespace app gateway-access=yes --overwrite

cat > "$BASE/manifests/10-gatewayclass.yaml" <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example
spec:
  controllerName: example.com/not-installed
EOF

cat > "$BASE/manifests/20-gateway.yaml" <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared
  namespace: gateway-system
spec:
  gatewayClassName: example
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              gateway-access: "yes"
EOF

cat > "$BASE/manifests/30-httproute.yaml" <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop
  namespace: app
spec:
  parentRefs:
    - name: shared
      namespace: gateway-system
  hostnames:
    - shop.example.local
  rules:
    - matches:
        - path: { type: PathPrefix, value: /api }
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: X-Route-By
                value: gateway-api
      backendRefs:
        - name: shop-api
          port: 8080
    - matches:
        - path: { type: PathPrefix, value: / }
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: X-Route-By
                value: gateway-api
      backendRefs:
        - name: shop-web
          port: 80
EOF

kubectl apply -f "$BASE/manifests/"
echo "Solucion aplicada. Corre el validador."
