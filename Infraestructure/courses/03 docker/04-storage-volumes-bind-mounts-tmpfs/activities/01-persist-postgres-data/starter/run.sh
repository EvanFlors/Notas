#!/usr/bin/env bash
# dkr-04-01 — starter: build the lab environment.
# Idempotent: safe to re-run after failures. Cleans previous state first.
#
# Note: we intentionally do NOT use `set -o pipefail` because some diagnostic
# pipelines use `grep -q` and the SIGPIPE on upstream readers would be flagged
# as a false failure.

set -eu

VOLUME="dkr04-pg-data"
CONTAINER="dkr04-pg"
PGPASS="devpass"
BACKUP="/tmp/dkr04-pg-backup.tar.gz"

say() { printf "\n== %s ==\n" "$*"; }

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: docker CLI not found; this lab requires Docker."
    exit 0
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "SKIP: Docker daemon not reachable; start Docker and retry."
    exit 0
  fi
}

cleanup_previous() {
  say "Cleanup previous state"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  rm -f "$BACKUP"
}

wait_pg_ready() {
  local name="$1"
  local tries=60
  local i
  for i in $(seq 1 "$tries"); do
    # Use psql itself as the readiness check — pg_isready can return 0 during
    # the init-db bootstrap phase, before the real server is listening.
    if docker exec -e PGPASSWORD="$PGPASS" "$name" \
         psql -U postgres -tAc "SELECT 1" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Postgres in $name never became ready after ${tries}s"
  docker logs --tail 50 "$name" || true
  return 1
}

require_docker

cleanup_previous

say "Step 1: create a named volume explicitly"
docker volume create "$VOLUME" >/dev/null
docker volume inspect "$VOLUME" --format 'volume={{.Name}} driver={{.Driver}} mountpoint={{.Mountpoint}}'

say "Step 2: run Postgres with the volume mounted on pgdata"
docker run -d --name "$CONTAINER" \
  --mount type=volume,source="$VOLUME",target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD="$PGPASS" \
  postgres:16-alpine >/dev/null
wait_pg_ready "$CONTAINER"

say "Step 3: create table + insert a marker row"
docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
  psql -U postgres -c "CREATE TABLE IF NOT EXISTS marcadores (nota text);"
docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
  psql -U postgres -c "INSERT INTO marcadores VALUES ('persisted-by-dkr04-01');"
docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
  psql -U postgres -c "SELECT nota FROM marcadores;"

say "Step 4: DESTROY the container (volume survives)"
docker rm -f "$CONTAINER" >/dev/null
echo "After rm, volume still listed:"
docker volume ls --filter name="$VOLUME"

say "Step 5: recreate a NEW container with the SAME volume"
docker run -d --name "$CONTAINER" \
  --mount type=volume,source="$VOLUME",target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD="$PGPASS" \
  postgres:16-alpine >/dev/null
wait_pg_ready "$CONTAINER"

say "Step 6: read the marker back from the new container"
docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
  psql -U postgres -c "SELECT nota FROM marcadores;"

say "Step 7: cold backup of the volume via an ephemeral busybox container"
docker run --rm \
  -v "$VOLUME":/data:ro \
  -v /tmp:/backup \
  busybox tar czf /backup/dkr04-pg-backup.tar.gz -C /data .
ls -la "$BACKUP"

say "DONE. Now run: bash tests/validate.sh"
