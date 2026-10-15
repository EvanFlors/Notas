#!/usr/bin/env bash
# Validate dkr-13-01: the running container 'dkr13-01-app' meets the six
# hardening controls via `docker inspect`. Optional Trivy scan if present.
#
# NOTE: deliberately NO `set -o pipefail`. We pipe docker inspect output into
# grep -q, and pipefail would surface SIGPIPE (141) when grep exits early.

BASE="${1:-${BASE_DIR:-/tmp/dkr13-01}}"
NAME="${CONTAINER_NAME:-dkr13-01-app}"
IMAGE="${IMAGE_NAME:-dkr13-01:v1}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-13-01-harden-fastapi-container under $BASE =="

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker no instalado" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "FAIL: dockerd no accesible" >&2
  exit 1
fi

if ! docker inspect "$NAME" >/dev/null 2>&1; then
  echo "FAIL: contenedor '$NAME' no existe. Ejecuta run.sh primero." >&2
  exit 1
fi

state="$(docker inspect "$NAME" --format '{{.State.Status}}')"
if [ "$state" != "running" ]; then
  echo "FAIL: contenedor '$NAME' no esta running (estado: $state)" >&2
  echo "Logs:"
  docker logs --tail 50 "$NAME" || true
  exit 1
fi

# -------- Check 1: USER no-root numerico --------
user="$(docker inspect "$NAME" --format '{{.Config.User}}')"
if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ] || [ "$user" = "0:0" ]; then
  note_fail "Config.User es '$user' (debe ser no-root, p.ej. '10001:10001')"
else
  note_ok "Config.User = $user (no-root)"
fi

# -------- Check 2: ReadonlyRootfs --------
ro="$(docker inspect "$NAME" --format '{{.HostConfig.ReadonlyRootfs}}')"
if [ "$ro" = "true" ]; then
  note_ok "HostConfig.ReadonlyRootfs = true"
else
  note_fail "HostConfig.ReadonlyRootfs = $ro (debe ser true, usa --read-only)"
fi

# -------- Check 3: CapDrop incluye ALL --------
capdrop="$(docker inspect "$NAME" --format '{{.HostConfig.CapDrop}}')"
if printf '%s' "$capdrop" | grep -q "ALL"; then
  note_ok "HostConfig.CapDrop incluye ALL ($capdrop)"
else
  note_fail "HostConfig.CapDrop = $capdrop (debe incluir ALL, usa --cap-drop=ALL)"
fi

# -------- Check 4: no-new-privileges --------
secopt="$(docker inspect "$NAME" --format '{{.HostConfig.SecurityOpt}}')"
if printf '%s' "$secopt" | grep -q "no-new-privileges:true"; then
  note_ok "HostConfig.SecurityOpt incluye no-new-privileges:true"
else
  note_fail "HostConfig.SecurityOpt = $secopt (añade --security-opt no-new-privileges:true)"
fi

# -------- Check 5: Memory > 0 --------
mem="$(docker inspect "$NAME" --format '{{.HostConfig.Memory}}')"
if [ "${mem:-0}" -gt 0 ] 2>/dev/null; then
  note_ok "HostConfig.Memory = $mem bytes"
else
  note_fail "HostConfig.Memory = $mem (debe ser > 0, usa --memory=256m)"
fi

# -------- Check 6: PidsLimit > 0 --------
pids="$(docker inspect "$NAME" --format '{{.HostConfig.PidsLimit}}')"
if [ "${pids:-0}" -gt 0 ] 2>/dev/null; then
  note_ok "HostConfig.PidsLimit = $pids"
else
  note_fail "HostConfig.PidsLimit = $pids (debe ser > 0, usa --pids-limit=100)"
fi

# -------- Bonus: HTTP /health responde --------
if command -v curl >/dev/null 2>&1; then
  http_body="$(curl -sS --max-time 3 http://127.0.0.1:8000/health 2>/dev/null || echo '')"
  if printf '%s' "$http_body" | grep -q '"status":"ok"'; then
    report+="  OK   -- /health responde {\"status\":\"ok\"}\n"
  else
    report+="  WARN -- /health no respondio como esperado (body: '$http_body')\n"
  fi
else
  report+="  SKIP -- curl no instalado, no se probo /health\n"
fi

# -------- Bonus: Trivy opcional --------
if command -v trivy >/dev/null 2>&1; then
  if trivy image --severity CRITICAL --exit-code 0 --ignore-unfixed --no-progress "$IMAGE" >/tmp/dkr13-01-trivy.out 2>&1; then
    if grep -q "CRITICAL: 0" /tmp/dkr13-01-trivy.out 2>/dev/null; then
      report+="  OK   -- trivy: 0 CRITICAL con fix en $IMAGE\n"
    else
      report+="  INFO -- trivy ejecutado (ver /tmp/dkr13-01-trivy.out)\n"
    fi
  else
    report+="  WARN -- trivy fallo (ver /tmp/dkr13-01-trivy.out)\n"
  fi
else
  report+="  SKIP -- trivy no instalado (opcional)\n"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total controles OK (requeridos: 6)."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
