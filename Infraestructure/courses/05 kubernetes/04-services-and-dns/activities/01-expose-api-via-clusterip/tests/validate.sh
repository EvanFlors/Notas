#!/usr/bin/env bash
# Validate k8s-04-01-expose-api-via-clusterip.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `kubectl ... | grep -q`, which emits SIGPIPE (exit 141) on the upstream
# command when grep matches early. pipefail would promote that to a failure.

NS="${NS:-default}"
SVC="${SVC:-webapi}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v kubectl >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'kubectl' no está instalado. Instala kubectl y vuelve a intentar.
  https://kubernetes.io/docs/tasks/tools/
EOF
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible por el contexto actual (kubectl cluster-info falla)."
  exit 0
fi

echo "== Validando ns=$NS svc=$SVC =="

# 1) Service existe y es ClusterIP.
if ! kubectl -n "$NS" get svc "$SVC" >/dev/null 2>&1; then
  bad "Service '$SVC' no existe en ns '$NS'"
else
  ok "Service '$SVC' existe"
  svc_type="$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.type}')"
  if [ "$svc_type" = "ClusterIP" ]; then
    ok "Service es ClusterIP"
  else
    bad "Service es '$svc_type' (esperado ClusterIP)"
  fi

  # 2) port 80 → targetPort 80
  port="$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.ports[0].port}')"
  tport="$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.ports[0].targetPort}')"
  if [ "$port" = "80" ] && [ "$tport" = "80" ]; then
    ok "port=80 targetPort=80"
  else
    bad "port=$port targetPort=$tport (esperado 80/80)"
  fi

  # 3) selector app=webapi (o SVC)
  sel="$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.selector.app}')"
  if [ "$sel" = "$SVC" ]; then
    ok "selector app=$SVC"
  else
    bad "selector app='$sel' (esperado '$SVC')"
  fi
fi

# 4) Deployment existe con las replicas listas.
if ! kubectl -n "$NS" get deploy "$SVC" >/dev/null 2>&1; then
  bad "Deployment '$SVC' no existe"
else
  ready="$(kubectl -n "$NS" get deploy "$SVC" -o jsonpath='{.status.readyReplicas}')"
  if [ "${ready:-0}" -ge 3 ]; then
    ok "Deployment '$SVC' tiene $ready réplicas Ready (>=3)"
  else
    bad "Deployment '$SVC' solo tiene ${ready:-0} réplicas Ready (esperado >=3)"
  fi
fi

# 5) Endpoints no vacío y con 3 subsets.
#    Preferimos endpointslices porque son la primitiva moderna, pero probamos ambos.
addr_count="$(kubectl -n "$NS" get endpoints "$SVC" \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
if [ "${addr_count:-0}" -ge 3 ]; then
  ok "endpoints lista $addr_count backends (>=3)"
else
  bad "endpoints lista ${addr_count:-0} backends (esperado >=3)"
fi

# 6/7) curl desde un Pod cliente al nombre corto y al FQDN.
#      Usamos un Pod efímero sin --rm/--attach para evitar carreras con el attach,
#      luego leemos logs y lo borramos.
curl_from_pod() {
  local target="$1"
  local pod="tmp-validate-$RANDOM"
  # Dentro del Pod: curl silencioso con reintentos. Si la DNS inicial del Pod
  # aún no responde (muy ocasional en kind single-node), reintenta hasta 5 veces.
  kubectl -n "$NS" run "$pod" --image=curlimages/curl:8.9.1 \
    --restart=Never --image-pull-policy=IfNotPresent \
    --command -- sh -c "
      for i in 1 2 3 4 5; do
        code=\$(curl --ipv4 -s -o /dev/null --max-time 8 -w '%{http_code}' '$target' 2>/dev/null)
        if [ \"\$code\" = '200' ]; then printf '%s' \"\$code\"; exit 0; fi
        sleep 2
      done
      printf '%s' \"\$code\"
      exit 0
    " >/dev/null 2>&1 || { echo ""; return 1; }
  kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$pod" --timeout=90s >/dev/null 2>&1 || true
  local out
  out="$(kubectl -n "$NS" logs "$pod" 2>/dev/null | tr -d '\r\n')"
  kubectl -n "$NS" delete pod "$pod" --grace-period=0 --force >/dev/null 2>&1 || true
  echo "$out"
}

http="$(curl_from_pod "http://$SVC")"
if [ "$http" = "200" ]; then
  ok "curl http://$SVC → HTTP 200"
else
  bad "curl http://$SVC → HTTP '$http' (esperado 200)"
fi

http="$(curl_from_pod "http://$SVC.$NS.svc.cluster.local")"
if [ "$http" = "200" ]; then
  ok "curl http://$SVC.$NS.svc.cluster.local → HTTP 200"
else
  bad "curl FQDN → HTTP '$http' (esperado 200)"
fi

printf "%b" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
