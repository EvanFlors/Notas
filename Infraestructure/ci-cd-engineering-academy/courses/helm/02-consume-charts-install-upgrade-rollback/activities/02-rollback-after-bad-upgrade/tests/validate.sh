#!/usr/bin/env bash
# Validate helm-02-02-rollback-after-bad-upgrade.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/helm-02-02}"
RELEASE="broken-app"
NS="rollback-lab"
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
  - Windows: choco install kubernetes-helm kubernetes-cli kind
Y asegura que Docker Desktop / colima / dockerd esté corriendo.
EOF
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde."
  exit 0
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "SKIP: no hay cluster alcanzable con el current-context."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- 1. Release existe ---
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

# --- 2. Historia: al menos 3 revisiones ---
history_json="$(helm history "$RELEASE" -n "$NS" -o json 2>/dev/null)"
rev_count="$(echo "$history_json" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null)"
if [ "${rev_count:-0}" -ge 3 ]; then
  ok "historia tiene $rev_count revisiones (>= 3)"
else
  bad "historia tiene ${rev_count:-0} revisiones (esperado >= 3)"
fi

# --- 3. Última revisión está deployed ---
last_status="$(echo "$history_json" | python3 -c '
import sys,json
d=json.load(sys.stdin)
d.sort(key=lambda r: r["revision"])
print(d[-1]["status"] if d else "")' 2>/dev/null)"
if [ "$last_status" = "deployed" ]; then
  ok "última revisión en status 'deployed'"
else
  bad "última revisión en status '$last_status' (esperado deployed)"
fi

# --- 4. Última revisión es un Rollback ---
last_desc="$(echo "$history_json" | python3 -c '
import sys,json
d=json.load(sys.stdin)
d.sort(key=lambda r: r["revision"])
print(d[-1].get("description","") if d else "")' 2>/dev/null)"
case "$last_desc" in
  Rollback\ to\ *)
    ok "última revisión descrita como '$last_desc'"
    ;;
  *)
    bad "última revisión descrita como '$last_desc' (esperado 'Rollback to ...')"
    ;;
esac

# --- 5. Valores de la última revisión == valores de la revisión 1 ---
LAST_REV="$(echo "$history_json" | python3 -c '
import sys,json
d=json.load(sys.stdin)
d.sort(key=lambda r: r["revision"])
print(d[-1]["revision"] if d else "")' 2>/dev/null)"

v1="$(helm get values "$RELEASE" -n "$NS" --revision 1 -o json 2>/dev/null)"
vL="$(helm get values "$RELEASE" -n "$NS" --revision "$LAST_REV" -o json 2>/dev/null)"
if [ -n "$v1" ] && [ "$v1" = "$vL" ]; then
  ok "valores de revisión $LAST_REV == valores de revisión 1"
else
  bad "valores de revisión $LAST_REV != valores de revisión 1 (el rollback no apunta a la rev 1)"
fi

# --- 6. Secret de release de la última revisión existe ---
if kubectl -n "$NS" get secret "sh.helm.release.v1.${RELEASE}.v${LAST_REV}" >/dev/null 2>&1; then
  ok "secret 'sh.helm.release.v1.${RELEASE}.v${LAST_REV}' presente"
else
  bad "secret 'sh.helm.release.v1.${RELEASE}.v${LAST_REV}' no existe"
fi

# --- 7. Snapshot ---
snap="$WORK/snapshot.md"
if [ ! -f "$snap" ]; then
  bad "no existe $snap"
else
  ok "snapshot.md existe"
  for section in "history" "values-rev1" "values-last" "release-secrets"; do
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
