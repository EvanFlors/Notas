#!/usr/bin/env bash
# Teardown of the dkr-04-01 lab.
set -eu

CONTAINER="dkr04-pg"
VOLUME="dkr04-pg-data"
BACKUP="/tmp/dkr04-pg-backup.tar.gz"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker volume rm "$VOLUME" >/dev/null 2>&1 || true
fi
rm -f "$BACKUP"
echo "Cleaned: container=$CONTAINER volume=$VOLUME backup=$BACKUP"
