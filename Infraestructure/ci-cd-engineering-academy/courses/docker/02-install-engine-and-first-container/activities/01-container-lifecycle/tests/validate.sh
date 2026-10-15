#!/usr/bin/env bash
# Validate dkr-02-01-container-lifecycle.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `docker inspect ... | grep -q ...`; if grep matches early it
# can trigger SIGPIPE on the upstream command (exit 141), and pipefail would
# promote that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/dkr-02-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: docker available? ---
if ! command -v docker >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'docker' no está instalado. Instala Docker siguiendo:
  - Linux:   https://docs.docker.com/engine/install/
  - macOS:   https://docs.docker.com/desktop/install/mac-install/  (o 'brew install colima')
  - Windows: https://docs.docker.com/desktop/install/windows-install/
Luego verifica: docker --version    (requiere >= 20.10)
EOF
  exit 0
fi

ver="$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
major="${ver%%.*}"
rest="${ver#*.}"
minor="${rest%%.*}"
if [ -z "$major" ] || [ -z "$minor" ]; then
  bad "no pude parsear 'docker --version' ($ver)"
elif [ "$major" -lt 20 ] || { [ "$major" -eq 20 ] && [ "$minor" -lt 10 ]; }; then
  bad "docker versión $ver < 20.10"
else
  ok "docker $ver detectado"
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde (docker info falla)."
  echo "       Arranca Docker Desktop / colima / 'sudo systemctl start docker'."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- 1. Contenedor cache ---
if ! docker ps --format '{{.Names}}' | grep -qx cache; then
  bad "contenedor 'cache' no está corriendo (docker ps)"
else
  ok "contenedor 'cache' corriendo"

  status="$(docker inspect --format '{{.State.Status}}' cache 2>/dev/null)"
  [ "$status" = "running" ] && ok "cache.State.Status = running" \
                            || bad "cache.State.Status = '$status' (esperado 'running')"

  image="$(docker inspect --format '{{.Config.Image}}' cache 2>/dev/null)"
  if [ "$image" = "redis:7-alpine" ]; then
    ok "cache.Config.Image = redis:7-alpine"
  else
    bad "cache.Config.Image = '$image' (esperado 'redis:7-alpine')"
  fi

  restart="$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' cache 2>/dev/null)"
  [ "$restart" = "unless-stopped" ] && ok "cache.RestartPolicy = unless-stopped" \
                                    || bad "cache.RestartPolicy = '$restart'"

  ports="$(docker inspect --format '{{json .NetworkSettings.Ports}}' cache 2>/dev/null)"
  if echo "$ports" | grep -q '"6379/tcp"' && echo "$ports" | grep -q '"HostPort":"16379"'; then
    ok "cache publica 16379:6379"
  else
    bad "cache no publica 16379:6379 (Ports=$ports)"
  fi

  env="$(docker inspect --format '{{json .Config.Env}}' cache 2>/dev/null)"
  if echo "$env" | grep -q 'REDIS_ROLE=primary'; then
    ok "cache tiene REDIS_ROLE=primary"
  else
    bad "cache no tiene REDIS_ROLE=primary"
  fi

  if docker exec cache redis-cli ping 2>/dev/null | grep -q PONG; then
    ok "redis responde PONG"
  else
    bad "redis no responde PONG"
  fi
fi

# --- 2. Contenedor oneshot ---
if ! docker ps -a --format '{{.Names}}' | grep -qx oneshot; then
  bad "contenedor 'oneshot' no existe"
else
  status="$(docker inspect --format '{{.State.Status}}' oneshot 2>/dev/null)"
  exitc="$(docker inspect --format '{{.State.ExitCode}}' oneshot 2>/dev/null)"
  [ "$status" = "exited" ] && ok "oneshot.State.Status = exited" \
                           || bad "oneshot.State.Status = '$status'"
  [ "$exitc"  = "0"      ] && ok "oneshot.ExitCode = 0" \
                           || bad "oneshot.ExitCode = '$exitc'"
fi

# --- 3. notas-inspect.md ---
notes="$WORK/notas-inspect.md"
if [ ! -f "$notes" ]; then
  bad "no existe $notes"
else
  ok "notas-inspect.md existe"
  for key in "State.Status" "State.Pid" "Config.Entrypoint" "Config.Cmd" \
             "HostConfig.RestartPolicy" "Config.Env" "NetworkSettings.Ports"; do
    if grep -q "$key" "$notes"; then
      ok "notas mencionan $key"
    else
      bad "notas no mencionan $key"
    fi
  done
  if grep -qi "comentario" "$notes"; then
    ok "notas contienen comentarios del alumno"
  else
    bad "notas no parecen tener comentarios ('_Comentario_'/'Comentario')"
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
