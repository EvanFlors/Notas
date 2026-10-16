#!/usr/bin/env bash
# Reference solution for helm-06-01-umbrella-for-dev-stack.
# Builds the expected final state at /tmp/helm06-act01/fastapi-app.

set -euo pipefail

TARGET="${1:-/tmp/helm06-act01/fastapi-app}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$(cd "$HERE/../starter/fastapi-app" && pwd)"

command -v helm >/dev/null || { echo "ERROR: helm not installed"; exit 1; }

echo "== Copy starter to $TARGET =="
rm -rf "$TARGET"
mkdir -p "$(dirname "$TARGET")"
cp -R "$STARTER" "$TARGET"

echo "== Patch Chart.yaml with dependency =="
cat > "$TARGET/Chart.yaml" <<'EOF'
apiVersion: v2
name: fastapi-app
description: FastAPI chart with optional Postgres dependency (dev umbrella mode)
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
    alias: db
    condition: db.enabled
EOF

echo "== Patch values.yaml with db block (default disabled) =="
cat >> "$TARGET/values.yaml" <<'EOF'

db:
  enabled: false
  auth:
    username: appuser
    password: dev-only-not-a-real-secret
    database: appdb
  primary:
    persistence:
      enabled: false
EOF

echo "== Write values-dev.yaml =="
cat > "$TARGET/values-dev.yaml" <<'EOF'
# dev: Postgres as subchart
db:
  enabled: true
EOF

echo "== Write values-prod.yaml =="
cat > "$TARGET/values-prod.yaml" <<'EOF'
# prod: Postgres is an external managed service (RDS). Do not install subchart.
db:
  enabled: false
EOF

echo "== helm dependency update =="
( cd "$TARGET" && helm dependency update )

echo
echo "Solution built at: $TARGET"
echo "Dev kinds:  $(helm template demo "$TARGET" -f "$TARGET/values-dev.yaml"  | awk '/^kind:/{print $2}' | sort -u | tr '\n' ' ')"
echo "Prod kinds: $(helm template demo "$TARGET" -f "$TARGET/values-prod.yaml" | awk '/^kind:/{print $2}' | sort -u | tr '\n' ' ')"
