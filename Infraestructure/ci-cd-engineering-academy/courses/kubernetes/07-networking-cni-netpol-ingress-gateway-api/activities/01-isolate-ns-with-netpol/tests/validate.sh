#!/usr/bin/env bash
# Validator: k8s-07-01-isolate-ns-with-netpol.
#
# NOTA: no `set -o pipefail`. Varios checks hacen `... | grep -q ...`
# y pipefail convertiria SIGPIPE del productor en falso FAIL.

NS="shop"
CLUSTER="${CLUSTER:-k8s07-act1}"
BASE="${BASE_DIR:-/tmp/k8s07-act1}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validando k8s-07-01-isolate-ns-with-netpol =="

if ! command -v kind    >/dev/null 2>&1; then echo "SKIP: kind no instalado.";    exit 0; fi
if ! command -v kubectl >/dev/null 2>&1; then echo "SKIP: kubectl no instalado."; exit 0; fi
if ! command -v docker  >/dev/null 2>&1; then echo "SKIP: docker no instalado.";  exit 0; fi
if ! docker info >/dev/null 2>&1;         then echo "SKIP: docker daemon no responde."; exit 0; fi

if ! kind get clusters | grep -qx "$CLUSTER"; then
  echo "SKIP: cluster kind '$CLUSTER' no existe. Corre starter/bootstrap.sh primero."
  exit 0
fi

kubectl config use-context "kind-${CLUSTER}" >/dev/null

# Check 1: namespace shop existe
if kubectl get ns "$NS" >/dev/null 2>&1; then
  note_ok "namespace '$NS' existe"
else
  note_fail "namespace '$NS' no existe"
fi

# Check 2: Pods presentes y Ready
for d in client api postgres; do
  ready="$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  if [ "${ready:-0}" -ge 1 ] 2>/dev/null; then
    note_ok "deployment '$d' ready"
  else
    note_fail "deployment '$d' no ready"
  fi
done

# Check 3: CNI con enforcement (Calico presente)
if kubectl -n calico-system get pods >/dev/null 2>&1 \
   || kubectl -n kube-system get pods -l k8s-app=calico-node 2>/dev/null | grep -q calico ; then
  note_ok "CNI con enforcement (Calico) presente"
else
  note_fail "no detecto Calico - NetworkPolicy NO se enforce en kindnet"
fi

# Check 4: hay al menos N NetworkPolicies en el namespace
NP_COUNT="$(kubectl -n "$NS" get networkpolicy --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [ "${NP_COUNT:-0}" -ge 3 ]; then
  note_ok "hay $NP_COUNT NetworkPolicies en '$NS'"
else
  note_fail "solo $NP_COUNT NetworkPolicies en '$NS' (se esperan >=3)"
fi

# Check 5: existe al menos un default-deny-like (podSelector {} con ingress+egress)
if kubectl -n "$NS" get networkpolicy -o json 2>/dev/null \
   | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(2)
items=d.get("items",[])
found=False
for it in items:
    s=it.get("spec",{})
    sel=s.get("podSelector",{})
    if sel in ({}, {"matchLabels":{}}) and set(s.get("policyTypes",[]))>={"Ingress","Egress"}:
        if not s.get("ingress") and not s.get("egress"):
            found=True; break
sys.exit(0 if found else 1)
' ; then
  note_ok "existe un default-deny (podSelector:{} + Ingress+Egress sin reglas)"
else
  note_fail "no encuentro default-deny completo en '$NS'"
fi

# Helpers para pruebas de trafico (reintenta un par de veces por tiempo de reconvergencia).
try_exec() {
  local tries="$1"; shift
  local cmd=("$@")
  for _ in $(seq 1 "$tries"); do
    if "${cmd[@]}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

# Check 6: client -> api (debe OK)
if try_exec 5 kubectl -n "$NS" exec deploy/client -- wget -qO- --timeout=3 http://api/ ; then
  note_ok "client -> api:80 OK"
else
  note_fail "client -> api:80 FAIL (deberia estar permitido)"
fi

# Check 7: api -> postgres (debe OK)
if try_exec 5 kubectl -n "$NS" exec deploy/api -- sh -c 'nc -zv -w3 postgres 5432' ; then
  note_ok "api -> postgres:5432 OK"
else
  note_fail "api -> postgres:5432 FAIL (deberia estar permitido)"
fi

# Check 8: client -> postgres (debe FALLAR = bloqueado por policy)
if kubectl -n "$NS" exec deploy/client -- sh -c 'nc -zv -w3 postgres 5432' >/dev/null 2>&1 ; then
  note_fail "client -> postgres:5432 PASA (deberia estar BLOQUEADO)"
else
  note_ok "client -> postgres:5432 bloqueado (correcto)"
fi

# Check 9: DNS resuelve desde client
if try_exec 5 kubectl -n "$NS" exec deploy/client -- nslookup -timeout=3 kubernetes.default ; then
  note_ok "DNS kubernetes.default resuelve desde client"
else
  note_fail "DNS no resuelve desde client (falta allow-dns?)"
fi

# Check 10: diagrama editado
DIAGRAM="$BASE/diagram.txt"
if [ -f "$DIAGRAM" ]; then
  if grep -q "Reemplaza este placeholder" "$DIAGRAM"; then
    note_fail "diagrama en $DIAGRAM sigue siendo el placeholder"
  else
    non_empty_lines="$(grep -c '[^[:space:]]' "$DIAGRAM" 2>/dev/null || echo 0)"
    if [ "$non_empty_lines" -ge 3 ]; then
      note_ok "diagrama presente ($non_empty_lines lineas)"
    else
      note_fail "diagrama demasiado corto"
    fi
  fi
else
  note_fail "no existe $DIAGRAM"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
