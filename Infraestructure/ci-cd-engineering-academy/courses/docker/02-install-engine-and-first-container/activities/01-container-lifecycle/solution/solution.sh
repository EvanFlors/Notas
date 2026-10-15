#!/usr/bin/env bash
# Solución de referencia para dkr-02-01-container-lifecycle.
# NO exportamos `set -o pipefail` porque algunos checks posteriores pueden
# usar `... | grep -q` (SIGPIPE con exit 141 produciría falsos negativos).

set -eu

WORK="/tmp/dkr-02-01"
mkdir -p "$WORK"
cd "$WORK"

# Limpieza previa por si hay restos.
docker rm -f cache oneshot >/dev/null 2>&1 || true

# Paso 1 — cache
docker run -d \
  --name cache \
  -p 16379:6379 \
  -e REDIS_ROLE=primary \
  --restart unless-stopped \
  redis:7-alpine

# Espera corta a que Redis esté listo.
for i in 1 2 3 4 5; do
  if docker exec cache redis-cli ping 2>/dev/null | grep -q PONG; then
    break
  fi
  sleep 0.5
done

docker exec cache redis-cli SET greeting "hola docker" >/dev/null
docker exec cache redis-cli SET module "dkr-02"      >/dev/null

# Paso 2 — notas-inspect.md
{
  echo "# notas-inspect — cache"
  echo
  echo "## State.Status"
  echo "\`\`\`"
  docker inspect --format '{{.State.Status}}' cache
  echo "\`\`\`"
  echo "_Comentario_: el daemon reporta el estado 'running'; es el daemon quien lo sabe, no el kernel directamente."
  echo
  echo "## State.Pid"
  echo "\`\`\`"
  docker inspect --format '{{.State.Pid}}' cache
  echo "\`\`\`"
  echo "_Comentario_: PID del proceso en el host; dentro del PID namespace del contenedor es PID 1."
  echo
  echo "## Config.Entrypoint"
  echo "\`\`\`"
  docker inspect --format '{{.Config.Entrypoint}}' cache
  echo "\`\`\`"
  echo "_Comentario_: script de entrypoint de la imagen oficial de Redis."
  echo
  echo "## Config.Cmd"
  echo "\`\`\`"
  docker inspect --format '{{.Config.Cmd}}' cache
  echo "\`\`\`"
  echo "_Comentario_: argumentos por default; combinado con el entrypoint arranca redis-server."
  echo
  echo "## HostConfig.RestartPolicy.Name"
  echo "\`\`\`"
  docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' cache
  echo "\`\`\`"
  echo "_Comentario_: 'unless-stopped' = el daemon lo reinicia salvo si yo lo paré manualmente."
  echo
  echo "## Config.Env"
  echo "\`\`\`"
  docker inspect --format '{{json .Config.Env}}' cache
  echo "\`\`\`"
  echo "_Comentario_: incluye las variables de la imagen y mi REDIS_ROLE=primary."
  echo
  echo "## NetworkSettings.Ports"
  echo "\`\`\`"
  docker inspect --format '{{json .NetworkSettings.Ports}}' cache
  echo "\`\`\`"
  echo "_Comentario_: mapping del puerto 6379 interno a 6379 del host en 0.0.0.0."
} > notas-inspect.md

# Paso 3 — oneshot
docker run --name oneshot redis:7-alpine redis-cli --version >/dev/null

echo "SETUP OK; corre tests/validate.sh ahora, ANTES de limpiar."
