#!/usr/bin/env bash
# Validator: k8s-07-02-publish-with-gateway-api.
#
# NOTA: no `set -o pipefail`. Varios checks hacen `... | grep -q ...`
# y pipefail convertiria SIGPIPE del productor en falso FAIL.
# La validacion es por manifiestos (schema + campos), no por trafico.

CLUSTER="${CLUSTER:-k8s07-act2}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validando k8s-07-02-publish-with-gateway-api =="

if ! command -v kind    >/dev/null 2>&1; then echo "SKIP: kind no instalado.";    exit 0; fi
if ! command -v kubectl >/dev/null 2>&1; then echo "SKIP: kubectl no instalado."; exit 0; fi
if ! command -v docker  >/dev/null 2>&1; then echo "SKIP: docker no instalado.";  exit 0; fi
if ! docker info >/dev/null 2>&1;         then echo "SKIP: docker daemon no responde."; exit 0; fi
if ! command -v python3 >/dev/null 2>&1;  then echo "SKIP: python3 no instalado."; exit 0; fi

if ! kind get clusters | grep -qx "$CLUSTER"; then
  echo "SKIP: cluster kind '$CLUSTER' no existe. Corre starter/bootstrap.sh primero."
  exit 0
fi
kubectl config use-context "kind-${CLUSTER}" >/dev/null

# Check 1: CRDs presentes
for crd in gatewayclasses.gateway.networking.k8s.io \
           gateways.gateway.networking.k8s.io \
           httproutes.gateway.networking.k8s.io ; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    note_ok "CRD $crd presente"
  else
    note_fail "CRD $crd ausente"
  fi
done

# Check 2: namespace app etiquetado
if kubectl get ns app -o jsonpath='{.metadata.labels.gateway-access}' 2>/dev/null | grep -qx yes ; then
  note_ok "namespace 'app' tiene label gateway-access=yes"
else
  note_fail "namespace 'app' NO tiene label gateway-access=yes"
fi

# Check 3: GatewayClass 'example' existe con el controllerName esperado
GC_JSON="$(kubectl get gatewayclass example -o json 2>/dev/null || echo '')"
if [ -n "$GC_JSON" ]; then
  note_ok "GatewayClass 'example' existe"
  if echo "$GC_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if d.get("spec",{}).get("controllerName")=="example.com/not-installed" else 1)
'; then
    note_ok "GatewayClass.spec.controllerName correcto"
  else
    note_fail "GatewayClass.spec.controllerName != example.com/not-installed"
  fi
else
  note_fail "GatewayClass 'example' no existe"
fi

# Check 4: Gateway 'shared' en gateway-system con listener HTTP:80 + allowedRoutes.Selector
TMP_GW="$(mktemp)"
kubectl -n gateway-system get gateway shared -o json >"$TMP_GW" 2>/dev/null || true
if [ -s "$TMP_GW" ]; then
  note_ok "Gateway 'shared' existe en gateway-system"
  if python3 - "$TMP_GW" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
sp=d.get("spec",{})
if sp.get("gatewayClassName")!="example": sys.exit(10)
listeners=sp.get("listeners",[])
if not listeners: sys.exit(11)
l=listeners[0]
if l.get("protocol")!="HTTP" or l.get("port")!=80: sys.exit(12)
ar=l.get("allowedRoutes",{}).get("namespaces",{})
if ar.get("from")!="Selector": sys.exit(13)
sel=ar.get("selector",{}).get("matchLabels",{})
if sel.get("gateway-access")!="yes": sys.exit(14)
sys.exit(0)
PY
  then
    note_ok "Gateway listener HTTP:80 + allowedRoutes Selector gateway-access=yes"
  else
    note_fail "Gateway campos clave incorrectos (gatewayClassName/listener/allowedRoutes)"
  fi
else
  note_fail "Gateway 'shared' no existe en gateway-system"
fi
rm -f "$TMP_GW"

# Check 5: HTTPRoute 'shop' en app con hostnames + 2 reglas + filtro + parentRef
TMP_HR="$(mktemp)"
kubectl -n app get httproute shop -o json >"$TMP_HR" 2>/dev/null || true
if [ -s "$TMP_HR" ]; then
  note_ok "HTTPRoute 'shop' existe en app"
  if python3 - "$TMP_HR" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
sp=d.get("spec",{})
prs=sp.get("parentRefs",[])
if not any(p.get("name")=="shared" and p.get("namespace")=="gateway-system" for p in prs):
    sys.exit(10)
if "shop.example.local" not in (sp.get("hostnames") or []):
    sys.exit(11)
rules=sp.get("rules",[])
if len(rules)<2:
    sys.exit(12)
r_api=None; r_root=None
for r in rules:
    for m in (r.get("matches") or []):
        p=m.get("path") or {}
        if p.get("type")=="PathPrefix" and p.get("value")=="/api":
            r_api=r
        if p.get("type")=="PathPrefix" and p.get("value")=="/":
            r_root=r
if not r_api: sys.exit(13)
if not r_root: sys.exit(14)
def has_backend(rule, name, port):
    for b in (rule.get("backendRefs") or []):
        if b.get("name")==name and b.get("port")==port:
            return True
    return False
if not has_backend(r_api,"shop-api",8080): sys.exit(15)
if not has_backend(r_root,"shop-web",80): sys.exit(16)
def has_filter(rule):
    for f in (rule.get("filters") or []):
        if f.get("type")=="RequestHeaderModifier":
            adds=(f.get("requestHeaderModifier") or {}).get("add",[]) or []
            for a in adds:
                if a.get("name")=="X-Route-By" and a.get("value")=="gateway-api":
                    return True
    return False
if not (has_filter(r_api) or has_filter(r_root)):
    sys.exit(17)
sys.exit(0)
PY
  then
    note_ok "HTTPRoute: parentRef + hostnames + 2 reglas con backends y filtro OK"
  else
    note_fail "HTTPRoute no cumple todas las condiciones (parentRef/hostnames/rules/filter)"
  fi
else
  note_fail "HTTPRoute 'shop' no existe en namespace app"
fi
rm -f "$TMP_HR"

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
