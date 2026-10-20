#!/usr/bin/env bash
# Bootstrap de k8s-07-01: cluster kind + Calico + ns shop + 3 Pods.
# Deja plantillas vacias de NetworkPolicy en /tmp/k8s07-act1/policies/.
set -eu

BASE="${1:-/tmp/k8s07-act1}"
CLUSTER="${CLUSTER:-k8s07-act1}"
NS="shop"

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

rm -rf "$BASE"
mkdir -p "$BASE/policies"

echo "== Crear cluster kind sin CNI default =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  cat > "$BASE/kind.yaml" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
EOF
  kind create cluster --name "$CLUSTER" --config "$BASE/kind.yaml"
else
  echo "Cluster '$CLUSTER' ya existe, reusando."
fi
kubectl config use-context "kind-${CLUSTER}"

echo "== Instalar Calico =="
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
kubectl apply -f - <<'EOF'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata: { name: default }
spec:
  calicoNetwork:
    ipPools:
      - cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
EOF
kubectl wait --for=condition=Ready node --all --timeout=180s

echo "== Namespace y Pods =="
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: client, labels: { role: client } }
spec:
  replicas: 1
  selector: { matchLabels: { role: client } }
  template:
    metadata: { labels: { role: client } }
    spec:
      containers:
        - name: tools
          image: busybox:1.36
          command: ["sh","-c","sleep 36000"]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, labels: { role: api } }
spec:
  replicas: 1
  selector: { matchLabels: { role: api } }
  template:
    metadata: { labels: { role: api } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [ { containerPort: 80 } ]
---
apiVersion: v1
kind: Service
metadata: { name: api }
spec:
  selector: { role: api }
  ports: [ { port: 80, targetPort: 80 } ]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: postgres, labels: { role: db } }
spec:
  replicas: 1
  selector: { matchLabels: { role: db } }
  template:
    metadata: { labels: { role: db } }
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - { name: POSTGRES_PASSWORD, value: demo }
          ports: [ { containerPort: 5432 } ]
---
apiVersion: v1
kind: Service
metadata: { name: postgres }
spec:
  selector: { role: db }
  ports: [ { port: 5432, targetPort: 5432 } ]
EOF

kubectl -n "$NS" rollout status deploy/client   --timeout=120s
kubectl -n "$NS" rollout status deploy/api      --timeout=120s
kubectl -n "$NS" rollout status deploy/postgres --timeout=180s

# netshoot-ish herramienta en client (busybox trae nc, wget, nslookup).

cat > "$BASE/policies/00-default-deny.yaml" <<'EOF'
# TODO: NetworkPolicy que selecciona TODOS los Pods del namespace shop
# y define policyTypes: ["Ingress","Egress"] SIN reglas listadas.
# Esto corta todo el trafico, en ambas direcciones, por default.
# Pista: podSelector: {}  significa "todos los pods del ns".
EOF

cat > "$BASE/policies/01-allow-dns.yaml" <<'EOF'
# TODO: NetworkPolicy que permite egress a kube-dns.
# Selector: podSelector: {}   (todos los pods del ns)
# policyTypes: ["Egress"]
# egress.to: namespaceSelector = kubernetes.io/metadata.name=kube-system
#             podSelector     = k8s-app=kube-dns  (en el MISMO item para AND logico)
# ports: UDP 53 y TCP 53.
EOF

cat > "$BASE/policies/02-allow-client-to-api.yaml" <<'EOF'
# TODO: Allow client->api en TCP/80.
# Puedes hacerlo con DOS NetworkPolicies (una ingress en api, otra egress en client)
# o combinar. Recordar: egress DNS ya esta cubierto por 01-allow-dns.
# Labels relevantes: role=client y role=api
EOF

cat > "$BASE/policies/03-allow-api-to-postgres.yaml" <<'EOF'
# TODO: Allow api->postgres en TCP/5432.
# Igual que arriba: una NetworkPolicy ingress en postgres (desde role=api)
# y una NetworkPolicy egress en api (hacia role=db) en el puerto 5432.
# NO abrir egress a internet desde postgres.
EOF

cat > "$BASE/NOTES.md" <<EOF
# k8s-07-01 scratch

Cluster:    kind "$CLUSTER"
Namespace:  "$NS"
Pods:       client (role=client), api (role=api), postgres (role=db)
Services:   api:80, postgres:5432

Edita los 4 archivos en $BASE/policies/ y aplica:
  kubectl apply -f $BASE/policies/

Verifica:
  kubectl -n $NS exec deploy/client -- wget -qO- --timeout=3 http://api/
  kubectl -n $NS exec deploy/api    -- nc -zv -w3 postgres 5432
  kubectl -n $NS exec deploy/client -- nc -zv -w3 postgres 5432    # debe fallar

Valida:
  bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/01-isolate-ns-with-netpol/tests/validate.sh

Limpieza:
  kind delete cluster --name $CLUSTER
  rm -rf $BASE
EOF

cat > "$BASE/diagram.txt" <<'EOF'
<!-- Reemplaza este placeholder con un diagrama ASCII del namespace shop. -->
<!-- Debe incluir: client, api, postgres, las flechas permitidas y las bloqueadas, -->
<!-- y la regla allow-dns hacia kube-system/kube-dns. -->
EOF

echo "== Bootstrap OK =="
echo "Scratch:  $BASE"
echo "Policies: $BASE/policies/*.yaml  (edita y aplica)"
