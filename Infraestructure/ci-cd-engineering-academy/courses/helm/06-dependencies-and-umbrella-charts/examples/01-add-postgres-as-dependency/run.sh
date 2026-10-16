#!/usr/bin/env bash
# Build a tiny app chart that declares bitnami/postgresql as a dependency,
# resolve it with `helm dependency update`, and render the composition.
#
# Requires internet access to charts.bitnami.com.

set -euo pipefail

WORK="${1:-/tmp/helm-ex-01}"
CHART_VERSION="18.12.4"

command -v helm >/dev/null || { echo "ERROR: helm not installed"; exit 1; }

echo "== 1. Scaffold working dir at $WORK =="
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

helm create myapp >/dev/null
# Strip auto-generated noise we don't need for the demo.
rm -f myapp/templates/ingress.yaml \
      myapp/templates/hpa.yaml \
      myapp/templates/serviceaccount.yaml \
      myapp/templates/tests/*.yaml
rmdir myapp/templates/tests 2>/dev/null || true

echo "== 2. Replace Chart.yaml with one that declares the dependency =="
cat > myapp/Chart.yaml <<'EOF'
apiVersion: v2
name: myapp
description: Demo app that depends on PostgreSQL
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
    alias: db
EOF

echo "== 3. Append db values (dummy credentials, dev-only) =="
cat >> myapp/values.yaml <<'EOF'

serviceAccount:
  create: false

db:
  auth:
    username: appuser
    password: dev-only-not-a-real-secret
    database: appdb
  primary:
    persistence:
      enabled: false
EOF

echo "== 4. helm dependency update =="
cd myapp
helm dependency update

echo
echo "== 5. Chart.lock contents =="
cat Chart.lock

echo
echo "== 6. charts/ contents =="
ls -la charts/

echo
echo "== 7. Render and count resource kinds =="
helm template demo . | awk '/^kind:/{print $2}' | sort | uniq -c

echo
echo "OK. Working dir left at $WORK (run cleanup.sh to remove)."
