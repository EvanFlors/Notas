#!/usr/bin/env bash
# Demo: default-deny NetworkPolicy + allow explicito en kind + Calico.
# Idempotente: se puede re-ejecutar.
#
# NOTA: no se usa `set -o pipefail`. Varias secciones hacen `... | grep -q ...`
# y pipefail convertiria SIGPIPE del productor en falso FAIL.
set -eu

CLUSTER="k8s07-netpol"
NS="app"

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

echo "== 0. Crear cluster kind con CNI deshabilitado =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  cat > /tmp/kind-${CLUSTER}.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
EOF
  kind create cluster --name "$CLUSTER" --config /tmp/kind-${CLUSTER}.yaml
else
  echo "Cluster '$CLUSTER' ya existe, reusando."
fi

kubectl config use-context "kind-${CLUSTER}"

echo
echo "== 1. Instalar Calico como CNI (enforce NetworkPolicy) =="
# Operator oficial de Tigera.
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
kubectl apply -f - <<'EOF'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
EOF

echo "Esperando a que los nodos esten Ready (Calico tarda ~60s) ..."
kubectl wait --for=condition=Ready node --all --timeout=180s

echo
echo "== 2. Namespace y Pods de prueba =="
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: server, labels: { app: server } }
spec:
  replicas: 1
  selector: { matchLabels: { app: server } }
  template:
    metadata: { labels: { app: server } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [ { containerPort: 80 } ]
---
apiVersion: v1
kind: Service
metadata: { name: server }
spec:
  selector: { app: server }
  ports: [ { port: 80, targetPort: 80 } ]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: client, labels: { app: client } }
spec:
  replicas: 1
  selector: { matchLabels: { app: client } }
  template:
    metadata: { labels: { app: client } }
    spec:
      containers:
        - name: busybox
          image: busybox:1.36
          command: ["sh","-c","sleep 36000"]
EOF

kubectl -n "$NS" rollout status deploy/server --timeout=120s
kubectl -n "$NS" rollout status deploy/client --timeout=120s

CLIENT_POD="$(kubectl -n "$NS" get pod -l app=client -o jsonpath='{.items[0].metadata.name}')"

probe() {
  local tag="$1"
  echo
  echo "== $tag =="
  # TCP a server
  if kubectl -n "$NS" exec "$CLIENT_POD" -- sh -c \
       'wget -qO- --timeout=5 http://server/ >/dev/null 2>&1'; then
    echo "client -> server:80       : OK"
  else
    echo "client -> server:80       : FAIL (timeout)"
  fi
  # DNS
  if kubectl -n "$NS" exec "$CLIENT_POD" -- sh -c \
       'nslookup -timeout=5 kubernetes.default >/dev/null 2>&1'; then
    echo "nslookup kubernetes.default: OK"
  else
    echo "nslookup kubernetes.default: FAIL"
  fi
}

probe "1. Sin policies"

echo
echo "== 3. Aplicar default-deny =="
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all }
spec:
  podSelector: {}
  policyTypes: ["Ingress","Egress"]
EOF

sleep 3
probe "2. default-deny-all"

echo
echo "== 4. Allow DNS egress =="
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns }
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
EOF

sleep 3
probe "3. + allow-dns"

echo
echo "== 5. Allow client -> server =="
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-client-to-server }
spec:
  podSelector: { matchLabels: { app: server } }
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels: { app: client }
      ports:
        - { protocol: TCP, port: 80 }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-client-egress-to-server }
spec:
  podSelector: { matchLabels: { app: client } }
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels: { app: server }
      ports:
        - { protocol: TCP, port: 80 }
    # Reaplicamos DNS por ser una policy aparte y aditiva
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
EOF

sleep 3
probe "4. + allow-client-to-server"

echo
echo "============================================================"
echo "El cluster '$CLUSTER' sigue corriendo para que explores."
echo "Borra cuando termines:  kind delete cluster --name $CLUSTER"
echo "============================================================"
