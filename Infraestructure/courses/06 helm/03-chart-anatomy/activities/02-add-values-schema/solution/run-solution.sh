#!/usr/bin/env bash
# Reference solution for helm-03-02-add-values-schema.
# Assumes the chart from helm-03-01 lives at $CHART_DIR
# (default: /tmp/helm-03-01/fastapi-app). Builds it if missing.

set -euo pipefail

CHART="${1:-${CHART_DIR:-/tmp/helm-03-01/fastapi-app}}"

if [ ! -d "$CHART" ]; then
  echo "Chart not found at $CHART; building via helm-03-01 solution..."
  SIBLING="$(cd "$(dirname "$0")/../../01-chart-for-fastapi/solution" && pwd)"
  bash "$SIBLING/run-solution.sh"
fi

cat > "$CHART/values.schema.json" <<'EOF'
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "title": "fastapi-app chart values",
  "type": "object",
  "required": ["image", "service"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "maximum": 50,
      "description": "Pod replicas."
    },
    "image": {
      "type": "object",
      "required": ["repository"],
      "properties": {
        "repository": { "type": "string", "minLength": 1 },
        "tag":        { "type": "string" },
        "pullPolicy": {
          "type": "string",
          "enum": ["Always", "IfNotPresent", "Never"]
        }
      },
      "additionalProperties": false
    },
    "service": {
      "type": "object",
      "required": ["port"],
      "properties": {
        "type": {
          "type": "string",
          "enum": ["ClusterIP", "NodePort", "LoadBalancer"]
        },
        "port":       { "type": "integer", "minimum": 1, "maximum": 65535 },
        "targetPort": { "type": "integer", "minimum": 1, "maximum": 65535 }
      },
      "additionalProperties": false
    },
    "resources": { "type": "object" },
    "probes": {
      "type": "object",
      "properties": {
        "path": { "type": "string", "pattern": "^/" },
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 }
      }
    }
  }
}
EOF

echo "Schema written at: $CHART/values.schema.json"

if command -v helm >/dev/null 2>&1; then
  helm template demo "$CHART" >/dev/null && echo "H1 (defaults) OK"
fi
