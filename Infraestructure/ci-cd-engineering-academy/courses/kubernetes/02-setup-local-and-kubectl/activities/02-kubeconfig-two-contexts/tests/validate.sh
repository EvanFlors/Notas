#!/usr/bin/env bash
# Validate k8s-02-02-kubeconfig-two-contexts.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/k8s-02-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
missing=""
command -v kubectl >/dev/null 2>&1 || missing+=" kubectl"
command -v kind    >/dev/null 2>&1 || missing+=" kind"
command -v docker  >/dev/null 2>&1 || missing+=" docker"

if [ -n "$missing" ]; then
  cat <<EOF
SKIP: faltan herramientas:$missing
Instala:
  - macOS:   brew install kind kubectl
  - Linux:   https://kind.sigs.k8s.io/docs/user/quick-start/#installation
             https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  - Windows: choco install kind kubernetes-cli
Y asegura que Docker Desktop / colima / dockerd esté corriendo.
EOF
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- 1. Clusters ---
clusters="$(kind get clusters 2>/dev/null)"
for c in lab-dev lab-stg; do
  if echo "$clusters" | grep -qx "$c"; then
    ok "cluster kind '$c' existe"
  else
    bad "cluster kind '$c' no existe"
  fi
done

# --- 2. Contextos ---
contexts="$(kubectl config get-contexts -o name 2>/dev/null)"
for ctx in kind-lab-dev kind-lab-stg; do
  if echo "$contexts" | grep -qx "$ctx"; then
    ok "contexto '$ctx' existe en kubeconfig"
  else
    bad "contexto '$ctx' NO existe en kubeconfig"
  fi
done

# --- 3 y 4. Namespace por default de cada contexto ---
check_ctx_ns() {
  local ctx="$1"; local want="$2"
  local got
  got="$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$ctx\")].context.namespace}" 2>/dev/null)"
  if [ "$got" = "$want" ]; then
    ok "$ctx tiene namespace '$want' por default"
  else
    bad "$ctx tiene namespace '$got' (esperado '$want')"
  fi
}
check_ctx_ns "kind-lab-dev" "apps-dev"
check_ctx_ns "kind-lab-stg" "apps-stg"

# --- 5. Namespaces y ConfigMaps marker ---
check_marker() {
  local ctx="$1"; local ns="$2"; local want="$3"
  if ! kubectl --context "$ctx" get namespace "$ns" >/dev/null 2>&1; then
    bad "namespace '$ns' no existe en '$ctx'"
    return
  fi
  ok "namespace '$ns' existe en '$ctx'"

  if ! kubectl --context "$ctx" -n "$ns" get cm env-marker >/dev/null 2>&1; then
    bad "configmap 'env-marker' no existe en $ctx/$ns"
    return
  fi

  local got
  got="$(kubectl --context "$ctx" -n "$ns" get cm env-marker -o jsonpath='{.data.env}' 2>/dev/null)"
  if [ "$got" = "$want" ]; then
    ok "env-marker.data.env = '$want' en $ctx/$ns"
  else
    bad "env-marker.data.env = '$got' en $ctx/$ns (esperado '$want')"
  fi
}
check_marker "kind-lab-dev" "apps-dev" "dev"
check_marker "kind-lab-stg" "apps-stg" "stg"

# --- 6. switch.sh ---
sw="$WORK/switch.sh"
if [ ! -f "$sw" ]; then
  bad "no existe $sw"
elif [ ! -x "$sw" ]; then
  bad "$sw existe pero no es ejecutable (chmod +x)"
else
  ok "$sw existe y es ejecutable"

  # Prueba ambos argumentos.
  for env in dev stg; do
    out="$("$sw" "$env" 2>/dev/null)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      bad "switch.sh $env salió con rc=$rc"
      continue
    fi
    # Verifica las tres líneas esperadas.
    if echo "$out" | grep -q "context" && echo "$out" | grep -q "kind-lab-$env"; then
      ok "switch.sh $env muestra context kind-lab-$env"
    else
      bad "switch.sh $env no muestra 'context ... kind-lab-$env'"
    fi
    if echo "$out" | grep -q "apps-$env"; then
      ok "switch.sh $env muestra namespace apps-$env"
    else
      bad "switch.sh $env no muestra namespace apps-$env"
    fi
    if echo "$out" | grep -qE "env[[:space:]]*:[[:space:]]*$env"; then
      ok "switch.sh $env imprime env=$env"
    else
      bad "switch.sh $env no imprime env=$env en la salida"
    fi
  done

  # Argumento inválido debe fallar (rc != 0).
  if "$sw" bogus >/dev/null 2>&1; then
    bad "switch.sh bogus NO falla; debería rechazar argumentos inválidos"
  else
    ok "switch.sh rechaza argumentos inválidos"
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
