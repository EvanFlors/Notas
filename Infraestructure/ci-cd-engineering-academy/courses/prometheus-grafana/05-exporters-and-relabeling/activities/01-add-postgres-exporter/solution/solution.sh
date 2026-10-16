#!/usr/bin/env bash
# Reference solution runner for obs-05-01.
# Copies the solution files to the starter directory and brings the stack up.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter"

cp "$HERE/docker-compose.yml" "$STARTER/docker-compose.yml"
cp "$HERE/prometheus.yml"     "$STARTER/prometheus.yml"

cd "$STARTER"
docker compose up -d
echo "Waiting 20s for Prometheus to scrape at least twice..."
sleep 20
echo "pg_up query:"
curl -fsS 'http://localhost:9090/api/v1/query?query=pg_up' || true
echo
echo "Done. Run bash ../tests/validate.sh"
