#!/usr/bin/env bash
# Validate k8s-04-02-debug-no-endpoints.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `kubectl ... | grep -q`, which emits SIGPIPE (exit 141) on the upstream
# command when grep matches early. pipefail would promote that to a failure.

NS="${NS:-default}"
SVC="${SVC:-web}"
WORK="${WORK_DIR:-/tmp/k8s-04-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: 'kubectl' no está instalado."
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible por el contexto actual."
  exit 0
fi

echo "== Validando ns=$NS svc=$SVC =="

# 1) Service y Deployment deben existir.
if ! kubectl -n "$NS" get svc "$SVC" >/dev/null 2>&1; then
  bad "Service '$SVC' no existe (¿corriste starter/build-broken.sh?)"
else
  ok "Service '$SVC' existe"
fi

if ! kubectl -n "$NS" get deploy "$SVC" >/dev/null 2>&1; then
  bad "Deployment '$SVC' no existe"
else
  ready="$(kubectl -n "$NS" get deploy "$SVC" -o jsonpath='{.status.readyReplicas}')"
  if [ "${ready:-0}" -ge 3 ]; then
    ok "Deployment '$SVC' tiene ${ready} réplicas Ready"
  else
    bad "Deployment '$SVC' solo tiene ${ready:-0} réplicas Ready"
  fi

  # Las labels de los Pods deben ser 'app=web' (sin alterar el Deployment).
  pod_label="$(kubectl -n "$NS" get deploy "$SVC" -o jsonpath='{.spec.template.metadata.labels.app}')"
  if [ "$pod_label" = "web" ]; then
    ok "Pods conservan 'app=web' (no se tocó el Deployment)"
  else
    bad "Pods tienen 'app=$pod_label'; la actividad pedía NO modificar el Deployment"
  fi
fi

# 2) Endpoints no vacío (fix aplicado).
addr_count="$(kubectl -n "$NS" get endpoints "$SVC" \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
if [ "${addr_count:-0}" -ge 3 ]; then
  ok "endpoints lista $addr_count backends (>=3) — fix aplicado"
else
  bad "endpoints lista ${addr_count:-0} backends (esperado >=3); el selector sigue mal"
fi

# 3) Selector del Service es 'app=web'.
sel="$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.selector.app}')"
if [ "$sel" = "web" ]; then
  ok "selector del Service es 'app=web'"
else
  bad "selector del Service es 'app=$sel' (esperado 'web')"
fi

# 4) curl desde Pod cliente responde 200.
#    Pod sin --attach para evitar carreras; leemos logs tras Succeeded.
curl_from_pod() {
  local target="$1"
  local pod="tmp-validate-$RANDOM"
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
  ok "curl http://$SVC desde Pod cliente → HTTP 200"
else
  bad "curl http://$SVC → HTTP '$http' (esperado 200)"
fi

# 5) Entregable escrito.
diag="$WORK/diagnostico.md"
if [ ! -f "$diag" ]; then
  bad "no existe $diag"
else
  ok "diagnostico.md existe"
  if grep -qi 'endpoint' "$diag"; then
    ok "diagnostico.md menciona 'endpoint'"
  else
    bad "diagnostico.md no menciona 'endpoint'"
  fi
  if grep -qi 'selector' "$diag"; then
    ok "diagnostico.md menciona 'selector'"
  else
    bad "diagnostico.md no menciona 'selector'"
  fi
  if grep -qi 'causa' "$diag"; then
    ok "diagnostico.md habla de 'causa'"
  else
    bad "diagnostico.md no describe la 'causa'"
  fi
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
