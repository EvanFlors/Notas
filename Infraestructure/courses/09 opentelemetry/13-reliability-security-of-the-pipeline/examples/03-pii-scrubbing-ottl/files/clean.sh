#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
docker compose -f "$HERE/docker-compose.yaml" down -v --remove-orphans 2>/dev/null || true
echo "Limpiado containers del compose del Ejemplo 03."
