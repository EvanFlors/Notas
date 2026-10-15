#!/usr/bin/env bash
# Solucion de referencia para k8s-07-01.
set -eu

BASE="${1:-/tmp/k8s07-act1}"
NS="shop"
CLUSTER="${CLUSTER:-k8s07-act1}"

if ! command -v kind    >/dev/null 2>&1; then echo "SKIP: kind no instalado.";    exit 0; fi
if ! command -v kubectl >/dev/null 2>&1; then echo "SKIP: kubectl no instalado."; exit 0; fi
if ! docker info >/dev/null 2>&1;         then echo "SKIP: docker daemon no responde."; exit 0; fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
bash "$HERE/starter/bootstrap.sh" "$BASE"
kubectl config use-context "kind-${CLUSTER}" >/dev/null

cat > "$BASE/policies/00-default-deny.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: shop }
spec:
  podSelector: {}
  policyTypes: ["Ingress","Egress"]
EOF

cat > "$BASE/policies/01-allow-dns.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns, namespace: shop }
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

cat > "$BASE/policies/02-allow-client-to-api.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: api-allow-from-client, namespace: shop }
spec:
  podSelector: { matchLabels: { role: api } }
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector: { matchLabels: { role: client } }
      ports:
        - { protocol: TCP, port: 80 }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: client-allow-to-api, namespace: shop }
spec:
  podSelector: { matchLabels: { role: client } }
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector: { matchLabels: { role: api } }
      ports:
        - { protocol: TCP, port: 80 }
EOF

cat > "$BASE/policies/03-allow-api-to-postgres.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: postgres-allow-from-api, namespace: shop }
spec:
  podSelector: { matchLabels: { role: db } }
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector: { matchLabels: { role: api } }
      ports:
        - { protocol: TCP, port: 5432 }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: api-allow-to-postgres, namespace: shop }
spec:
  podSelector: { matchLabels: { role: api } }
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector: { matchLabels: { role: db } }
      ports:
        - { protocol: TCP, port: 5432 }
EOF

kubectl apply -f "$BASE/policies/"

cat > "$BASE/diagram.txt" <<'EOF'
Namespace: shop  (default-deny-all + allow-dns global)

                    kube-system/kube-dns:53  (UDP+TCP)
                             ^
                             |  allow-dns  (todos los Pods)
                             |
   +---------+   TCP/80    +-------+   TCP/5432    +-----------+
   | client  | ----------> |  api  | ------------> | postgres  |
   |role=cli |             |role=api|              |  role=db  |
   +---------+             +--------+              +-----------+
         X                                               ^
         |                                               |
         +---------- client -> postgres BLOQUEADO -------+
                   (no hay allow explicito)

postgres: sin egress (no puede resolver DNS ni salir a internet).
EOF

echo "Solucion aplicada. Corre el validador."
