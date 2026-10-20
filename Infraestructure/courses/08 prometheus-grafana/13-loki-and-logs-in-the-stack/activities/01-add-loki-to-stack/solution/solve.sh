#!/usr/bin/env bash
# Reference solution: write the final files into the lab dir and bring it up.
set -eu

BASE="${1:-/tmp/obs13-lab01}"
if [ ! -d "$BASE" ]; then
  echo "ERROR: run starter/setup.sh $BASE first"; exit 1
fi

cat > "$BASE/docker-compose.yaml" <<'YAML'
services:
  loki:
    image: grafana/loki:3.2.0
    container_name: lab01-loki
    command: -config.file=/etc/loki/loki-config.yaml
    ports: ["3100:3100"]
    volumes:
      - ./loki-config.yaml:/etc/loki/loki-config.yaml:ro

  alloy:
    image: grafana/alloy:v1.4.2
    container_name: lab01-alloy
    command: [run, --server.http.listen-addr=0.0.0.0:12345, /etc/alloy/config.alloy]
    ports: ["12345:12345"]
    volumes:
      - ./alloy-config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on: [loki]

  grafana:
    image: grafana/grafana:11.3.0
    container_name: lab01-grafana
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports: ["3000:3000"]
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

cat > "$BASE/loki-config.yaml" <<'YAML'
auth_enabled: false
server: {http_listen_port: 3100}
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring: {instance_addr: 127.0.0.1, kvstore: {store: inmemory}}
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index: {prefix: index_, period: 24h}
limits_config:
  retention_period: 24h
  allow_structured_metadata: true
compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
YAML

cat > "$BASE/alloy-config.alloy" <<'ALLOY'
discovery.docker "containers" {
  host             = "unix:///var/run/docker.sock"
  refresh_interval = "5s"
}
discovery.relabel "containers" {
  targets = discovery.docker.containers.targets
  rule { source_labels = ["__meta_docker_container_label_app"]; target_label = "app" }
  rule { source_labels = ["__meta_docker_container_label_env"]; target_label = "env" }
  rule { source_labels = ["app"]; regex = ".+"; action = "keep" }
}
loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.relabel.containers.output
  forward_to = [loki.write.default.receiver]
  labels     = { job = "docker" }
}
loki.write "default" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}
ALLOY

cat > "$BASE/grafana/provisioning/datasources/datasources.yaml" <<'YAML'
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
YAML

cd "$BASE"
docker compose up -d
echo "Done. Validate with: bash <repo>/activities/01-add-loki-to-stack/tests/validate.sh $BASE"
