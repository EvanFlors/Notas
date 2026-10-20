#!/usr/bin/env bash
# Build the base infra-repo for argo-07-01. Idempotent.
# Creates /tmp/argo-07-01/infra-repo with envs/{dev,stg,prod,_shared}.

set -e

BASE="${BASE:-/tmp/argo-07-01}"
REPO="$BASE/infra-repo"

rm -rf "$BASE"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.email "dev@example.com"
git config user.name "Dev"

for env in dev stg prod; do
  mkdir -p "envs/$env"
  cat > "envs/$env/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels: { app: myapp, env: $env }
spec:
  replicas: 1
  selector: { matchLabels: { app: myapp } }
  template:
    metadata: { labels: { app: myapp, env: $env } }
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
EOF
done

mkdir -p envs/_shared
echo "# shared manifests, not an env" > envs/_shared/README.md

git add .
git commit -q -m "init: envs/{dev,stg,prod} + _shared"

echo "OK: base repo built at $REPO"
echo "Now write $BASE/appset.yaml following the activity README."
