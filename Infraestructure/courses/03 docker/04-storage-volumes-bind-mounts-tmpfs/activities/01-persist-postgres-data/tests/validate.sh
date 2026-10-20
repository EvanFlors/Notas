#!/usr/bin/env bash
# dkr-04-01 — validator.
# Verifies that: the named volume exists, the container is running with that
# volume mounted at pgdata, the marker row persisted after a destroy+recreate
# cycle, and that the cold backup .tar.gz is readable.
#
# NOTE: deliberately no `set -o pipefail` because several checks use
# `grep -q` which triggers SIGPIPE on upstream commands and would be flagged.

set -eu

VOLUME="dkr04-pg-data"
CONTAINER="dkr04-pg"
PGPASS="devpass"
BACKUP="/tmp/dkr04-pg-backup.tar.gz"

passed=0
failed=0
report=""

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI not installed — nothing to validate."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon not reachable — nothing to validate."
  exit 0
fi

# 1. Volume exists.
check "Volume $VOLUME exists" \
  bash -c "docker volume inspect $VOLUME"

# 2. Container is running.
check "Container $CONTAINER is running" \
  bash -c "docker inspect -f '{{.State.Running}}' $CONTAINER | grep -q '^true$'"

# 3. Container has the volume mounted at pgdata.
# We list all mounts "name=dest" per line, then grep for the exact pair.
mounts_dump="$(docker inspect -f '{{range .Mounts}}{{.Name}}={{.Destination}}{{"\n"}}{{end}}' "$CONTAINER" 2>/dev/null || true)"
if printf '%s' "$mounts_dump" | grep -qx "$VOLUME=/var/lib/postgresql/data"; then
  report+="Mount $VOLUME -> /var/lib/postgresql/data: OK\n"; passed=$((passed+1))
else
  report+="Mount $VOLUME -> /var/lib/postgresql/data: FAIL (got '$(printf '%s' "$mounts_dump" | tr '\n' ';')')\n"
  failed=$((failed+1))
fi

# 4. Marker row survived the destroy+recreate cycle.
if docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
     psql -U postgres -tAc "SELECT nota FROM marcadores WHERE nota='persisted-by-dkr04-01'" \
     2>/dev/null | grep -q "persisted-by-dkr04-01"; then
  report+="Marker row survived rm+recreate: OK\n"; passed=$((passed+1))
else
  report+="Marker row survived rm+recreate: FAIL\n"; failed=$((failed+1))
fi

# 5. Backup exists and is a readable tar.gz containing PG_VERSION.
if [ -f "$BACKUP" ] && tar tzf "$BACKUP" 2>/dev/null | grep -q "PG_VERSION"; then
  report+="Backup $BACKUP valid (contains PG_VERSION): OK\n"; passed=$((passed+1))
else
  report+="Backup $BACKUP valid: FAIL\n"; failed=$((failed+1))
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -eq 0 ] || exit 1
exit 0
