#!/usr/bin/env bash
# Validate k8s-05-01-config-and-secret-for-capstone.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q` or `grep -c`; `grep -q` can short-circuit and cause SIGPIPE
# (exit 141) on the upstream command, which pipefail would wrongly turn into
# a pipeline failure (false negative).

NS="${NAMESPACE:-capstone}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  cat <<'EOF'
SKIP: 'kubectl' no está instalado.
Instala kubectl: https://kubernetes.io/docs/tasks/tools/
EOF
  exit 0
fi

if ! kubectl version --client >/dev/null 2>&1; then
  echo "SKIP: 'kubectl version --client' falló."
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  cat <<'EOF'
SKIP: no se detecta un cluster alcanzable.
Arranca uno con:
  kind create cluster --name k8s-05
y vuelve a correr este validador.
EOF
  exit 0
fi

echo "== Validando namespace: $NS =="

# --- 1. Namespace existe -----------------------------------------------------
if kubectl get ns "$NS" >/dev/null 2>&1; then
  ok "namespace '$NS' existe"
else
  bad "namespace '$NS' no existe"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

# --- 2. ConfigMap app-config -------------------------------------------------
if kubectl -n "$NS" get configmap app-config >/dev/null 2>&1; then
  ok "ConfigMap 'app-config' existe"
  for k in LOG_LEVEL APP_PORT GREETING; do
    val="$(kubectl -n "$NS" get configmap app-config -o jsonpath="{.data.$k}" 2>/dev/null)"
    if [ -n "$val" ]; then
      ok "app-config.data.$k = '$val'"
    else
      bad "app-config.data.$k vacío o ausente"
    fi
  done
else
  bad "ConfigMap 'app-config' no existe"
fi

# --- 3. Secret db ------------------------------------------------------------
if kubectl -n "$NS" get secret db >/dev/null 2>&1; then
  ok "Secret 'db' existe"
  stype="$(kubectl -n "$NS" get secret db -o jsonpath='{.type}' 2>/dev/null)"
  [ "$stype" = "Opaque" ] && ok "Secret 'db' type=Opaque" \
                          || bad "Secret 'db' type='$stype' (esperado Opaque)"
  if kubectl -n "$NS" get secret db -o jsonpath='{.data.password}' 2>/dev/null | grep -q .; then
    ok "Secret 'db' tiene clave 'password'"
  else
    bad "Secret 'db' no tiene clave 'password'"
  fi
else
  bad "Secret 'db' no existe"
fi

# --- 4. Deployment app -------------------------------------------------------
if ! kubectl -n "$NS" get deploy app >/dev/null 2>&1; then
  bad "Deployment 'app' no existe"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi
ok "Deployment 'app' existe"

ready="$(kubectl -n "$NS" get deploy app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
[ "$ready" = "1" ] && ok "Deployment 'app' tiene 1 ready replica" \
                   || bad "Deployment 'app' ready='$ready' (esperado 1)"

# --- 5. Deployment NO inyecta password como env -----------------------------
env_json="$(kubectl -n "$NS" get deploy app -o json 2>/dev/null)"
# Fail si cualquier container tiene un env con secretKeyRef hacia password.
leak_env="$(echo "$env_json" | grep -c '"secretKeyRef"' || true)"
if [ "$leak_env" -gt 0 ]; then
  bad "el Deployment inyecta un Secret como env var (secretKeyRef aparece $leak_env veces)"
else
  ok "el Deployment NO usa secretKeyRef (Secret no está como env)"
fi

# --- 6. Secret montado como volume ------------------------------------------
if echo "$env_json" | grep -q '"secretName": *"db"'; then
  ok "el Deployment monta Secret 'db' como volume"
else
  bad "el Deployment no monta Secret 'db' como volume"
fi

mode="$(echo "$env_json" | python3 -c '
import json,sys
d = json.load(sys.stdin)
for v in d["spec"]["template"]["spec"].get("volumes", []):
    s = v.get("secret") or {}
    if s.get("secretName") == "db":
        print(s.get("defaultMode",""))
        break
' 2>/dev/null)"
if [ "$mode" = "256" ]; then
  ok "volumen Secret 'db' tiene defaultMode 0400 (decimal 256)"
else
  bad "volumen Secret 'db' defaultMode='$mode' (esperado 256 = 0400)"
fi

# --- 7. Verificación en vivo dentro del Pod ---------------------------------
POD="$(kubectl -n "$NS" get pod -l app=app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$POD" ]; then
  bad "no se encontró Pod con label app=app"
else
  ok "Pod detectado: $POD"

  # Env tiene los 3 config keys
  envout="$(kubectl -n "$NS" exec "$POD" -- sh -c 'env' 2>/dev/null)"
  for k in LOG_LEVEL APP_PORT GREETING; do
    if echo "$envout" | grep -q "^$k="; then
      ok "env del Pod incluye $k"
    else
      bad "env del Pod NO incluye $k"
    fi
  done

  # Env NO tiene la password (ninguna var contiene el valor dummy)
  if echo "$envout" | grep -q 'dummy-not-real'; then
    bad "la password se filtró como env var dentro del Pod"
  else
    ok "la password NO está en el env del Pod"
  fi

  # Archivo existe con mode 0400
  # Note: /etc/app/secret/db-password is a symlink into ..data/; sin -L stat
  # devuelve el permiso del symlink (0777). Hay que seguirlo (-L).
  perms="$(kubectl -n "$NS" exec "$POD" -- sh -c 'stat -L -c "%a" /etc/app/secret/db-password 2>/dev/null || stat -L -f "%A" /etc/app/secret/db-password 2>/dev/null' 2>/dev/null)"
  if [ "$perms" = "400" ]; then
    ok "/etc/app/secret/db-password tiene mode 0400"
  else
    bad "/etc/app/secret/db-password mode='$perms' (esperado 400)"
  fi

  # Contenido del archivo = valor dummy
  content="$(kubectl -n "$NS" exec "$POD" -- cat /etc/app/secret/db-password 2>/dev/null)"
  if [ "$content" = "dummy-not-real-ABC123" ]; then
    ok "/etc/app/secret/db-password tiene el valor esperado"
  else
    bad "/etc/app/secret/db-password contenido inesperado"
  fi

  # Logs tienen "password_len"
  if kubectl -n "$NS" logs "$POD" 2>/dev/null | grep -q '"password_len"'; then
    ok "logs del Pod incluyen 'password_len' (la app leyó el archivo)"
  else
    bad "logs del Pod NO incluyen 'password_len'"
  fi
fi

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
