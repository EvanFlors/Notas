#!/usr/bin/env bash
# Validate k8s-03-01-deploy-fastapi.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `kubectl get ... | grep -q ...`; if grep matches early it
# can trigger SIGPIPE (exit 141) on the upstream kubectl command, and pipefail
# would promote that to a failure of the whole pipeline — a false negative.

NS="${NS:-k8s-03-01}"
NAME="fastapi-stub"
WANTED_IMAGE="nginxdemos/hello:plain-text"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v kubectl >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'kubectl' no está instalado. Instala:
  - macOS:   brew install kubectl
  - Linux:   https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  - Windows: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
Y además kind (o un cluster local equivalente):
  https://kind.sigs.k8s.io/docs/user/quick-start/
EOF
  exit 0
fi

if ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no hay contexto activo en kubeconfig."
  echo "       Arranca uno con:  kind create cluster --name k8s-03"
  exit 0
fi
if ! kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible (/readyz no responde)."
  echo "       Arranca uno con:  kind create cluster --name k8s-03"
  exit 0
fi

echo "== Validando namespace=$NS deployment=$NAME =="

# --- 1. Namespace ---
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  bad "namespace '$NS' no existe"
  echo -e "$report"; echo "RESULT: FAIL"; exit 1
fi
ok "namespace '$NS' existe"

# --- 2. Deployment existe ---
if ! kubectl -n "$NS" get deployment "$NAME" >/dev/null 2>&1; then
  bad "deployment '$NAME' no existe en namespace '$NS'"
  echo -e "$report"; echo "RESULT: FAIL"; exit 1
fi
ok "deployment '$NAME' existe"

# --- 3. Spec fields ---
replicas="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.replicas}' 2>/dev/null)"
[ "$replicas" = "3" ] && ok "spec.replicas = 3" || bad "spec.replicas = '$replicas' (esperado 3)"

strategy="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.strategy.type}' 2>/dev/null)"
[ "$strategy" = "RollingUpdate" ] && ok "spec.strategy.type = RollingUpdate" \
                                  || bad "spec.strategy.type = '$strategy'"

maxSurge="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)"
maxUnav="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)"
[ "$maxSurge" = "1" ] && ok "maxSurge = 1" || bad "maxSurge = '$maxSurge' (esperado 1)"
[ "$maxUnav" = "0" ] && ok "maxUnavailable = 0" || bad "maxUnavailable = '$maxUnav' (esperado 0)"

histLimit="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.revisionHistoryLimit}' 2>/dev/null)"
[ "$histLimit" = "5" ] && ok "revisionHistoryLimit = 5" \
                       || bad "revisionHistoryLimit = '$histLimit' (esperado 5)"

image="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
[ "$image" = "$WANTED_IMAGE" ] && ok "image = $WANTED_IMAGE" \
                               || bad "image = '$image' (esperado '$WANTED_IMAGE')"

cname="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null)"
[ "$cname" = "web" ] && ok "container[0].name = web" || bad "container[0].name = '$cname'"

cport="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null)"
[ "$cport" = "80" ] && ok "containerPort = 80" || bad "containerPort = '$cport'"

# --- 4. Labels / selector contract ---
sel_app="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)"
sel_cmp="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.selector.matchLabels.component}' 2>/dev/null)"
[ "$sel_app" = "fastapi-stub" ] && ok "selector.matchLabels.app = fastapi-stub" \
                                || bad "selector.matchLabels.app = '$sel_app'"
[ "$sel_cmp" = "web" ] && ok "selector.matchLabels.component = web" \
                      || bad "selector.matchLabels.component = '$sel_cmp'"

tpl_app="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)"
tpl_cmp="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.metadata.labels.component}' 2>/dev/null)"
[ "$tpl_app" = "fastapi-stub" ] && ok "template.labels.app = fastapi-stub" \
                                || bad "template.labels.app = '$tpl_app'"
[ "$tpl_cmp" = "web" ] && ok "template.labels.component = web" \
                      || bad "template.labels.component = '$tpl_cmp'"

# --- 5. Rollout completo (ready = desired) ---
desired="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.replicas}' 2>/dev/null)"
ready="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
[ "$ready" = "3" ] && [ "$desired" = "3" ] \
  && ok "status: ready=3 desired=3" \
  || bad "status: ready='$ready' desired='$desired' (esperado 3/3)"

# --- 6. Al menos 2 ReplicaSets => hubo rollout ---
rs_count="$(kubectl -n "$NS" get rs -l app=fastapi-stub -o name 2>/dev/null | wc -l | tr -d ' ')"
if [ "${rs_count:-0}" -ge 2 ]; then
  ok "replicaSets observados = $rs_count (hubo rollout)"
else
  bad "solo $rs_count ReplicaSet(s); hiciste el rolling update del paso 5?"
fi

# --- 7. Pods Running ---
running="$(kubectl -n "$NS" get pods -l app=fastapi-stub --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')"
[ "${running:-0}" = "3" ] && ok "3 Pods Running" || bad "Pods Running = $running (esperado 3)"

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
