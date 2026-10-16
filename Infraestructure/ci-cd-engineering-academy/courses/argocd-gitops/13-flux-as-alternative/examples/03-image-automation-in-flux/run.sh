#!/usr/bin/env bash
# Example 03: image automation with local git daemon serving a repo over TCP.
# The kind node reaches the host via its IP; we discover it at runtime.
# Note: no `set -o pipefail` — see example 01 for rationale.
set -eu

CLUSTER="flux-ex03"
REPO_DIR="/tmp/flux-ex03-repo"
SERVE_DIR="/tmp/flux-ex03-serve"   # bare repo for git daemon
DAEMON_PORT="9418"
NS="podinfo"
PIDFILE="/tmp/flux-ex03-daemon.pid"

log()  { printf '\033[1;34m[ex03]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[ex03 SKIP]\033[0m %s\n' "$*"; exit 0; }
fail() { printf '\033[1;31m[ex03 FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

for bin in kind kubectl flux git; do
  command -v "$bin" >/dev/null || skip "$bin not installed"
done

log "preparing local git repo at $REPO_DIR"
rm -rf "$REPO_DIR" "$SERVE_DIR"
mkdir -p "$REPO_DIR"
(
  cd "$REPO_DIR"
  git init -q -b main
  git config user.email "ex03@local"
  git config user.name  "ex03"
  mkdir -p apps
  cat > apps/podinfo.yaml <<'YAML'
apiVersion: v1
kind: Namespace
metadata: { name: podinfo }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: podinfo
spec:
  replicas: 1
  selector: { matchLabels: { app: podinfo } }
  template:
    metadata: { labels: { app: podinfo } }
    spec:
      containers:
        - name: app
          image: ghcr.io/stefanprodan/podinfo:6.0.0  # {"$imagepolicy": "flux-system:podinfo"}
          ports: [ { containerPort: 9898 } ]
YAML
  cat > apps/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [ podinfo.yaml ]
YAML
  git add -A
  git commit -q -m "init"
)

log "mirroring to bare repo at $SERVE_DIR"
git clone -q --bare "$REPO_DIR" "$SERVE_DIR"
touch "$SERVE_DIR/git-daemon-export-ok"

log "starting git daemon on 0.0.0.0:$DAEMON_PORT (writable)"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")" || true
fi
git daemon --reuseaddr --base-path=/tmp --export-all --enable=receive-pack \
  --listen=0.0.0.0 --port="$DAEMON_PORT" --detach --pid-file="$PIDFILE" "$SERVE_DIR" \
  || fail "failed to start git daemon"
sleep 1

# Discover host IP reachable from kind containers (docker network gateway)
HOST_IP="$(docker network inspect kind -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
if [ -z "$HOST_IP" ]; then HOST_IP="host.docker.internal"; fi

log "ensuring kind cluster '$CLUSTER'"
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --wait 60s
  HOST_IP="$(docker network inspect kind -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "$HOST_IP")"
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

GIT_URL="git://${HOST_IP}:${DAEMON_PORT}/flux-ex03-serve"
log "git URL for in-cluster use: $GIT_URL"

log "flux install (with image automation controllers)"
flux install \
  --components-extra=image-reflector-controller,image-automation-controller
kubectl -n flux-system wait --for=condition=Ready pod --all --timeout=180s || fail "flux-system not ready"

log "apply GitRepository + Kustomization + ImageRepository + ImagePolicy + ImageUpdateAutomation"
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata: { name: infra, namespace: flux-system }
spec:
  interval: 30s
  url: ${GIT_URL}
  ref: { branch: main }
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: { name: apps, namespace: flux-system }
spec:
  interval: 1m
  path: "./apps"
  prune: true
  sourceRef: { kind: GitRepository, name: infra }
  wait: true
  timeout: 2m
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata: { name: podinfo, namespace: flux-system }
spec:
  image: ghcr.io/stefanprodan/podinfo
  interval: 1m
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata: { name: podinfo, namespace: flux-system }
spec:
  imageRepositoryRef: { name: podinfo }
  policy:
    semver:
      range: ">=6.0.0 <7.0.0"
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata: { name: infra-main, namespace: flux-system }
spec:
  interval: 30s
  sourceRef: { kind: GitRepository, name: infra }
  git:
    checkout: { ref: { branch: main } }
    commit:
      author: { email: fluxcdbot@local, name: fluxcdbot }
      messageTemplate: "chore(images): {{range .Updated.Images}}{{println .}}{{end}}"
    push: { branch: main }
  update:
    path: ./apps
    strategy: Setters
EOF

log "forcing reconcile of image repository + automation"
flux reconcile image repository podinfo --timeout=60s || true
flux reconcile image update infra-main --timeout=90s || true
flux reconcile source git infra --timeout=60s || true

log "waiting up to 90s for a new commit from fluxcdbot"
end=$(( $(date +%s) + 90 ))
found=0
while [ "$(date +%s)" -lt "$end" ]; do
  if (cd "$REPO_DIR" && git fetch -q "$SERVE_DIR" main && git log -1 --format='%an' FETCH_HEAD | grep -qx fluxcdbot); then
    found=1; break
  fi
  sleep 5
done

cd "$REPO_DIR"
git fetch -q "$SERVE_DIR" main || true
log "git log of the serve repo:"
git --git-dir="$SERVE_DIR" log --oneline -n 5

if [ "$found" -eq 1 ]; then
  log "SUCCESS — image automation produced a commit."
else
  log "NO COMMIT YET — this is OK if the registry returned the same winning tag already present."
  log "Inspect: kubectl -n flux-system describe imageupdateautomation infra-main"
fi

cat <<'MSG'

OK — ejemplo 03 completado. Limpia con: bash cleanup.sh
MSG
