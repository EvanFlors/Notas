#!/usr/bin/env bash
# Demonstrate `condition:` toggling a subchart on/off from values.

set -euo pipefail

WORK="${1:-/tmp/helm-ex-02}"

command -v helm >/dev/null || { echo "ERROR: helm not installed"; exit 1; }

echo "== 1. Scaffold at $WORK =="
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

helm create myapp >/dev/null
rm -f myapp/templates/ingress.yaml \
      myapp/templates/hpa.yaml \
      myapp/templates/serviceaccount.yaml \
      myapp/templates/tests/*.yaml
rmdir myapp/templates/tests 2>/dev/null || true

cat > myapp/Chart.yaml <<'EOF'
apiVersion: v2
name: myapp
description: Demo app with optional Postgres dependency
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

# Production-safe default: subchart disabled.
cat >> myapp/values.yaml <<'EOF'

serviceAccount:
  create: false

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

cat > myapp/values-dev.yaml <<'EOF'
db:
  enabled: true
EOF

cd myapp
echo "== 2. helm dependency update =="
helm dependency update

echo
echo "== 3. Render with defaults (db.enabled=false) =="
default_kinds=$(helm template demo . | awk '/^kind:/{print $2}' | sort -u | tr '\n' ' ')
echo "kinds: $default_kinds"

echo
echo "== 4. Render with values-dev.yaml (db.enabled=true) =="
dev_kinds=$(helm template demo . -f values-dev.yaml | awk '/^kind:/{print $2}' | sort -u | tr '\n' ' ')
echo "kinds: $dev_kinds"

echo
echo "== 5. Assertions =="
has_default_sts=$(echo "$default_kinds" | grep -c StatefulSet || true)
has_dev_sts=$(echo "$dev_kinds" | grep -c StatefulSet || true)

if [ "$has_default_sts" -eq 0 ] && [ "$has_dev_sts" -ge 1 ]; then
  echo "OK: StatefulSet appears only when db.enabled=true"
else
  echo "FAIL: expected StatefulSet only in dev render"
  echo "  default has StatefulSet: $has_default_sts (want 0)"
  echo "  dev has StatefulSet:     $has_dev_sts (want >=1)"
  exit 1
fi
