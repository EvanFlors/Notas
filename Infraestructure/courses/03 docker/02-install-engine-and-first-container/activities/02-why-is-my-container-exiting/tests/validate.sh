#!/usr/bin/env bash
# Validate dkr-02-02-why-is-my-container-exiting.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Checks use patterns
# like `docker ... | grep -q`, which emit SIGPIPE (exit 141) on the upstream
# command when grep matches early. pipefail would promote that to a failure.

WORK="${WORK_DIR:-/tmp/dkr-02-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v docker >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'docker' no está instalado. Instala Docker siguiendo:
  - Linux:   https://docs.docker.com/engine/install/
  - macOS:   https://docs.docker.com/desktop/install/mac-install/
  - Windows: https://docs.docker.com/desktop/install/windows-install/
Verifica con: docker --version    (requiere >= 20.10)
EOF
  exit 0
fi

ver="$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
major="${ver%%.*}"
rest="${ver#*.}"
minor="${rest%%.*}"
if [ -z "${major:-}" ] || [ -z "${minor:-}" ]; then
  bad "no pude parsear 'docker --version' ($ver)"
elif [ "$major" -lt 20 ] || { [ "$major" -eq 20 ] && [ "$minor" -lt 10 ]; }; then
  bad "docker versión $ver < 20.10"
else
  ok "docker $ver detectado"
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde (docker info falla)."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- Casos rotos reproducidos ---
for name in case-1 case-2 case-3; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    status="$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)"
    if [ "$status" = "exited" ]; then
      ok "$name existe y está exited"
    else
      bad "$name existe pero status='$status' (esperado 'exited')"
    fi
  else
    bad "$name no existe (debes reproducirlo)"
  fi
done

# --- fix-1: running ---
if docker ps --format '{{.Names}}' | grep -qx fix-1; then
  ok "fix-1 corriendo"
  # No usó --restart para falsear.
  rp="$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' fix-1 2>/dev/null)"
  if [ "$rp" = "always" ] || [ "$rp" = "on-failure" ] || [ "$rp" = "unless-stopped" ]; then
    bad "fix-1 usa --restart='$rp'; eso enmascara el bug. Usa un comando de larga vida."
  else
    ok "fix-1 no usa --restart para falsear"
  fi
else
  bad "fix-1 no está corriendo"
fi

# --- fix-2: exited con exit 0 ---
if docker ps -a --format '{{.Names}}' | grep -qx fix-2; then
  status="$(docker inspect --format '{{.State.Status}}' fix-2 2>/dev/null)"
  exitc="$(docker inspect --format '{{.State.ExitCode}}' fix-2 2>/dev/null)"
  if [ "$status" = "exited" ] && [ "$exitc" = "0" ]; then
    ok "fix-2 exited con ExitCode=0"
  else
    bad "fix-2 status='$status' exit='$exitc' (esperado exited/0)"
  fi
else
  bad "fix-2 no existe"
fi

# --- fix-3: running ---
if docker ps --format '{{.Names}}' | grep -qx fix-3; then
  ok "fix-3 corriendo"
  rp="$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' fix-3 2>/dev/null)"
  if [ "$rp" = "always" ] || [ "$rp" = "on-failure" ] || [ "$rp" = "unless-stopped" ]; then
    bad "fix-3 usa --restart='$rp'; eso enmascara el bug."
  else
    ok "fix-3 no usa --restart para falsear"
  fi
else
  bad "fix-3 no está corriendo"
fi

# --- diagnostico.md ---
diag="$WORK/diagnostico.md"
if [ ! -f "$diag" ]; then
  bad "no existe $diag"
else
  ok "diagnostico.md existe"
  for section in "case-1" "case-2" "case-3"; do
    if grep -q "$section" "$diag"; then
      ok "diagnostico.md menciona $section"
    else
      bad "diagnostico.md no menciona $section"
    fi
  done
  if grep -qi "causa" "$diag"; then
    ok "diagnostico.md habla de 'causa'"
  else
    bad "diagnostico.md no usa 'Causa:'"
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
