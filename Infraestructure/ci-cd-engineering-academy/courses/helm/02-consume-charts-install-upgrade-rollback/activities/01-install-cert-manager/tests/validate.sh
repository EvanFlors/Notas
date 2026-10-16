#!/usr/bin/env bash
# Validate helm-02-01-install-cert-manager.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/helm-02-01}"
RELEASE="cert-manager"
NS="cert-manager"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: tools available? ---
missing=""
command -v helm    >/dev/null 2>&1 || missing+=" helm"
command -v kubectl >/dev/null 2>&1 || missing+=" kubectl"
command -v docker  >/dev/null 2>&1 || missing+=" docker"

if [ -n "$missing" ]; then
  cat <<EOF
SKIP: faltan herramientas:$missing
Instala:
  - macOS:   brew install helm kubectl kind
  - Linux:   https://helm.sh/docs/intro/install/
             https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
             https://kind.sigs.k8s.io/docs/user/quick-start/#installation
  - Windows: choco install kubernetes-helm kubernetes-cli kind
Y asegura que Docker Desktop / colima / dockerd esté corriendo.
EOF
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde. Arranca Docker Desktop / colima / 'sudo systemctl start docker'."
  exit 0
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "SKIP: no hay cluster alcanzable con el current-context. Crea uno con 'kind create cluster --name helm-02'."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- 1. Release existe en el namespace esperado ---
if ! helm status "$RELEASE" -n "$NS" >/dev/null 2>&1; then
  bad "release '$RELEASE' no existe en namespace '$NS'"
  echo -e "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL"
  exit 1
else
  ok "release '$RELEASE' existe en '$NS'"
fi

# --- 2. Revision == 1 ---
rev="$(helm list -n "$NS" --filter "^${RELEASE}\$" -o json 2>/dev/null \
       | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["revision"] if d else "")' 2>/dev/null)"
if [ "$rev" = "1" ]; then
  ok "release en revisión 1"
else
  bad "release en revisión '$rev' (esperado 1)"
fi

# --- 3. Status == deployed ---
status="$(helm list -n "$NS" --filter "^${RELEASE}\$" -o json 2>/dev/null \
          | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["status"] if d else "")' 2>/dev/null)"
if [ "$status" = "deployed" ]; then
  ok "release status = deployed"
else
  bad "release status = '$status' (esperado deployed)"
fi

# --- 4. Namespace existe ---
if kubectl get namespace "$NS" >/dev/null 2>&1; then
  ok "namespace '$NS' existe"
else
  bad "namespace '$NS' no existe"
fi

# --- 5. Deployment del controller Ready ---
ready="$(kubectl -n "$NS" get deploy cert-manager -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
if [ "${ready:-0}" -ge 1 ]; then
  ok "deployment cert-manager tiene $ready réplica(s) Ready"
else
  bad "deployment cert-manager no tiene réplicas Ready"
fi

# --- 6. CRDs instaladas ---
if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  ok "CRD certificates.cert-manager.io presente"
else
  bad "CRD certificates.cert-manager.io ausente (¿instalaste con crds.enabled=true?)"
fi

# --- 7. Secret del release ---
if kubectl -n "$NS" get secret "sh.helm.release.v1.${RELEASE}.v1" >/dev/null 2>&1; then
  ok "secret del release 'sh.helm.release.v1.${RELEASE}.v1' presente"
else
  bad "secret del release 'sh.helm.release.v1.${RELEASE}.v1' no existe"
fi

# --- 8. Snapshot ---
snap="$WORK/snapshot.md"
if [ ! -f "$snap" ]; then
  bad "no existe $snap"
else
  ok "snapshot.md existe"
  for section in "release" "status" "release-secret" "crds"; do
    if grep -q "^## $section" "$snap"; then
      ok "snapshot contiene sección '## $section'"
    else
      bad "snapshot no contiene sección '## $section'"
    fi
  done
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
