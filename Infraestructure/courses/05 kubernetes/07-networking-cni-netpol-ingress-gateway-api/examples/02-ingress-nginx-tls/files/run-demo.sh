#!/usr/bin/env bash
# Demo: ingress-nginx + TLS autofirmado en kind.
# Idempotente.
#
# NOTA: no `set -o pipefail` por el patron `... | grep -q ...`.
set -eu

CLUSTER="k8s07-ingress"
HOST="app.example.local"
HTTPS_PORT="8443"
HTTP_PORT="80"

if ! command -v kind >/dev/null 2>&1; then
  echo "SKIP: kind no instalado."
  exit 0
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no instalado."
  exit 0
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

SCRATCH="/tmp/k8s07-ingress-demo"
mkdir -p "$SCRATCH"

echo "== 0. Crear cluster kind con port mappings =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  cat > "$SCRATCH/kind.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: ${HTTP_PORT}
        protocol: TCP
      - containerPort: 443
        hostPort: ${HTTPS_PORT}
        protocol: TCP
EOF
  kind create cluster --name "$CLUSTER" --config "$SCRATCH/kind.yaml"
else
  echo "Cluster '$CLUSTER' ya existe, reusando."
fi

kubectl config use-context "kind-${CLUSTER}"

echo
echo "== 1. Instalar ingress-nginx (manifest para kind) =="
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml

echo "Esperando a ingress-nginx-controller (puede tardar ~90s) ..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo
echo "== 2. Generar cert autofirmado para $HOST =="
openssl req -x509 -nodes -newkey rsa:2048 -days 7 \
  -keyout "$SCRATCH/tls.key" -out "$SCRATCH/tls.crt" \
  -subj "/CN=${HOST}/O=lab" \
  -addext "subjectAltName=DNS:${HOST}" 2>/dev/null

kubectl create secret tls web-tls \
  --cert="$SCRATCH/tls.crt" --key="$SCRATCH/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "== 3. Desplegar app 'web' =="
kubectl apply -f - <<'EOF'
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
  ports: [ { port: 80, targetPort: 80 } ]
EOF

kubectl rollout status deploy/web --timeout=120s

echo
echo "== 4. Crear Ingress con TLS =="
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts: ["${HOST}"]
      secretName: web-tls
  rules:
    - host: ${HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port: { number: 80 }
EOF

sleep 5

echo
echo "== 5. Probar =="
echo "HTTP (debe redirigir a HTTPS):"
curl -sS -o /dev/null -w "  status=%{http_code}\n" \
  -H "Host: ${HOST}" "http://localhost:${HTTP_PORT}/"

echo "HTTPS (debe responder 200):"
# -k para aceptar cert autofirmado; --resolve para forzar el host sin DNS
curl -sS -o "$SCRATCH/body.html" -w "  status=%{http_code}\n" \
  -k --resolve "${HOST}:${HTTPS_PORT}:127.0.0.1" \
  "https://${HOST}:${HTTPS_PORT}/"

echo "Titulo recibido:"
grep -o '<title>[^<]*</title>' "$SCRATCH/body.html" || echo "  (sin <title>)"

echo "Cert presentado:"
echo | openssl s_client -connect "localhost:${HTTPS_PORT}" -servername "${HOST}" 2>/dev/null \
  | openssl x509 -noout -subject -dates || true

echo
echo "============================================================"
echo "Cluster '$CLUSTER' sigue corriendo. Para borrar:"
echo "  kind delete cluster --name $CLUSTER"
echo "  rm -rf $SCRATCH"
echo "============================================================"
