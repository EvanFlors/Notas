#!/usr/bin/env bash
# Demonstrate what Chart.lock pins and how `build` vs `update` differ.
#
# Serves a tiny local chart repo over HTTP (python3 http.server on 127.0.0.1)
# so Helm 4 can consume it the same way it would a remote repo. No internet
# access needed — only localhost.

set -euo pipefail

WORK="${1:-/tmp/helm-ex-03}"
PORT="${PORT:-8765}"
REPO="$WORK/repo"
APP_A="$WORK/checkout-a/myapp"
APP_B="$WORK/checkout-b/myapp"
REPO_URL="http://127.0.0.1:$PORT"

command -v helm >/dev/null || { echo "ERROR: helm not installed"; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 required to serve repo"; exit 1; }

cleanup_server() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  helm repo remove helm-ex-03-local >/dev/null 2>&1 || true
}
trap cleanup_server EXIT

echo "== 1. Build a local chart repo with two versions of 'mydep' =="
rm -rf "$WORK"
mkdir -p "$REPO" "$(dirname "$APP_A")"

make_mydep() {
  local ver="$1" out="$2"
  rm -rf "$out"
  mkdir -p "$out/mydep/templates"
  cat > "$out/mydep/Chart.yaml" <<EOF
apiVersion: v2
name: mydep
description: Tiny local dependency for lock demo
type: application
version: $ver
appVersion: "$ver"
EOF
  cat > "$out/mydep/values.yaml" <<EOF
message: "hello from mydep $ver"
EOF
  cat > "$out/mydep/templates/configmap.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-mydep
data:
  message: {{ .Values.message | quote }}
EOF
  ( cd "$out" && helm package mydep -d "$REPO" >/dev/null )
}

STAGE="$WORK/stage"
make_mydep "1.0.0" "$STAGE/v1.0.0"
make_mydep "1.1.0" "$STAGE/v1.1.0"
helm repo index "$REPO" >/dev/null
echo "repo now contains:"
ls "$REPO"

echo
echo "== 1b. Serve the repo on $REPO_URL =="
( cd "$REPO" && python3 -m http.server "$PORT" --bind 127.0.0.1 ) >/dev/null 2>&1 &
SERVER_PID=$!
# Wait for the server to come up.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "$REPO_URL/index.yaml" -o /dev/null 2>/dev/null; then break; fi
  sleep 0.2
done
curl -fsS "$REPO_URL/index.yaml" -o /dev/null || { echo "ERROR: local repo did not come up"; exit 1; }
echo "repo served OK"

# Register with helm so `dependency build` can look it up by URL.
helm repo remove helm-ex-03-local >/dev/null 2>&1 || true
helm repo add helm-ex-03-local "$REPO_URL" >/dev/null

echo
echo "== 2. Create parent chart 'myapp' pinned to ~1.0.0 =="
mkdir -p "$APP_A/templates"
cat > "$APP_A/Chart.yaml" <<EOF
apiVersion: v2
name: myapp
description: Parent chart for lock demo
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: mydep
    version: "~1.0.0"
    repository: "$REPO_URL"
EOF
cat > "$APP_A/values.yaml" <<'EOF'
mydep:
  message: "parent override"
EOF

echo
echo "== 3. helm dependency update (resolves to 1.0.0) =="
( cd "$APP_A" && helm dependency update . )
echo "--- Chart.lock after first update ---"
cat "$APP_A/Chart.lock"

echo
echo "== 4. Publish a new patch version 1.0.1 in the repo =="
make_mydep "1.0.1" "$STAGE/v1.0.1"
helm repo index "$REPO" >/dev/null
helm repo update helm-ex-03-local >/dev/null
echo "repo now contains:"
ls "$REPO"

echo
echo "== 5. Simulate 'second checkout': copy app to another dir =="
mkdir -p "$(dirname "$APP_B")"
cp -R "$APP_A" "$APP_B"
rm -rf "$APP_B/charts"   # second checkout has no vendored tgz yet

echo "== 6. In checkout B: helm dependency BUILD (reads lock) =="
( cd "$APP_B" && helm dependency build . )
echo "checkout B vendored:"
ls "$APP_B/charts/"

echo
echo "== 7. In checkout A: helm dependency UPDATE (bumps within range) =="
( cd "$APP_A" && helm dependency update . )
echo "--- Chart.lock after second update ---"
cat "$APP_A/Chart.lock"
echo "checkout A vendored:"
ls "$APP_A/charts/"

echo
echo "== 8. Compare =="
ver_b=$(ls "$APP_B/charts/" | sed -n 's/mydep-\(.*\)\.tgz/\1/p')
ver_a=$(ls "$APP_A/charts/" | sed -n 's/mydep-\(.*\)\.tgz/\1/p')
echo "checkout B (build from old lock) -> mydep $ver_b"
echo "checkout A (update after bump)   -> mydep $ver_a"

if [ "$ver_b" = "1.0.0" ] && [ "$ver_a" = "1.0.1" ]; then
  echo "OK: lock pinned B to 1.0.0 while A updated to 1.0.1"
else
  echo "FAIL: expected B=1.0.0 and A=1.0.1"
  exit 1
fi
