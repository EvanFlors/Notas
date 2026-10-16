#!/usr/bin/env bash
# Copy a baseline stack (Grafana + demo-app only) to a scratch dir.
# No `set -o pipefail` on purpose.
set -eu

BASE="${1:-/tmp/obs13-lab01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$BASE/grafana/provisioning/datasources"
mkdir -p "$BASE/demo-app"

# Baseline docker-compose: Grafana + demo-app only. No Loki, no Alloy.
cat > "$BASE/docker-compose.yaml" <<'YAML'
services:
  grafana:
    image: grafana/grafana:11.3.0
    container_name: lab01-grafana
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning

  demo-app:
    image: python:3.12-slim
    container_name: lab01-demo-app
    labels:
      app: demo-app
      env: dev
    command: ["python", "/app/app.py"]
    volumes:
      - ./demo-app:/app:ro
YAML

cat > "$BASE/grafana/provisioning/datasources/datasources.yaml" <<'YAML'
apiVersion: 1
datasources: []
# TODO: add Loki here
YAML

cat > "$BASE/demo-app/app.py" <<'PY'
import json, random, sys, time, uuid
LEVELS = ["info"]*7 + ["warn"]*2 + ["error"]*1
while True:
    lvl = random.choice(LEVELS)
    print(json.dumps({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": lvl,
        "msg": {"info":"ok","warn":"slow","error":"db timeout"}[lvl],
        "request_id": str(uuid.uuid4()),
    }), flush=True)
    time.sleep(2)
PY

echo "Starter copied to $BASE"
echo "Edit docker-compose.yaml to add loki + alloy, then: cd $BASE && docker compose up -d"
