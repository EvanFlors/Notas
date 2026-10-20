#!/usr/bin/env bash
# Build the three OutOfSync diagnostic scenarios under /tmp/argo-03-02/.
# Each scenario is self-contained and OFFLINE (no cluster required).
#
# Note: no `set -o pipefail` — simple file writes don't need it, and the
# project convention avoids pipefail interacting with grep -q elsewhere.

set -eu

BASE="${1:-/tmp/argo-03-02}"
rm -rf "$BASE"
mkdir -p "$BASE/scenario-a" "$BASE/scenario-b" "$BASE/scenario-c"

echo "Building 3 scenarios under $BASE"

############################################
# SCENARIO A — moving targetRevision (HEAD)
############################################
cat > "$BASE/scenario-a/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capstone-api-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/acme/capstone-infra.git
    path: envs/prod/api
    # This Application was created by someone who did not know HEAD is a trap.
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: capstone-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
YAML

cat > "$BASE/scenario-a/desired-in-git.yaml" <<'YAML'
# Rendered from envs/prod/api at the CURRENT default branch of the repo.
# The default branch was recently switched from "main" to "develop" by an admin;
# "develop" contains an in-progress image tag (:next) that was not reviewed.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-api
  namespace: capstone-prod
spec:
  replicas: 3
  selector:
    matchLabels: { app: capstone-api }
  template:
    metadata:
      labels: { app: capstone-api }
    spec:
      containers:
        - name: api
          image: ghcr.io/acme/capstone-api:next   # unreviewed, from develop
YAML

cat > "$BASE/scenario-a/live-in-cluster.yaml" <<'YAML'
# What was actually running until yesterday's reconcile (from the OLD default
# branch "main", which pinned a reviewed tag).
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-api
  namespace: capstone-prod
spec:
  replicas: 3
  selector:
    matchLabels: { app: capstone-api }
  template:
    metadata:
      labels: { app: capstone-api }
    spec:
      containers:
        - name: api
          image: ghcr.io/acme/capstone-api:v1.4.2
YAML

cat > "$BASE/scenario-a/evidence.md" <<'MD'
# Scenario A — operational evidence

- Yesterday 14:03 UTC: platform admin changed the repo default branch from `main`
  to `develop` for an unrelated reason (reorg of long-lived branches).
- 14:07 UTC: Argo CD alerts: `capstone-api-prod` OutOfSync.
- `argocd app diff capstone-api-prod` shows ONLY `image: ...:v1.4.2 -> :next`.
- No commit was made to `envs/prod/api/` in the last 24h.
- No PR was merged touching the prod folder.

Yet the "desired" state in the diff is NOT what the team expected.
MD

cat > "$BASE/scenario-a/report.md" <<'MD'
# Report — Scenario A

## Causa raíz (una línea)
TODO: en una línea, qué causó el OutOfSync.

## Corrección mínima aplicada
- TODO: qué cambiaste y por qué.

## Riesgo si no se corrige
TODO: qué puede ir mal si se deja así.
MD

############################################
# SCENARIO B — HPA mutating replicas
############################################
cat > "$BASE/scenario-b/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capstone-api-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/acme/capstone-infra.git
    path: envs/dev/api
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: capstone-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
  # NOTE: no ignoreDifferences at all.
YAML

cat > "$BASE/scenario-b/desired-in-git.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-api
  namespace: capstone-dev
spec:
  replicas: 3
  selector:
    matchLabels: { app: capstone-api }
  template:
    metadata:
      labels: { app: capstone-api }
    spec:
      containers:
        - name: api
          image: ghcr.io/acme/capstone-api:v1.4.2
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: capstone-api
  namespace: capstone-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: capstone-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
YAML

cat > "$BASE/scenario-b/live-in-cluster.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-api
  namespace: capstone-dev
spec:
  replicas: 7            # HPA scaled up due to CPU
  selector:
    matchLabels: { app: capstone-api }
  template:
    metadata:
      labels: { app: capstone-api }
    spec:
      containers:
        - name: api
          image: ghcr.io/acme/capstone-api:v1.4.2
YAML

cat > "$BASE/scenario-b/evidence.md" <<'MD'
# Scenario B — operational evidence

- `argocd app diff capstone-api-dev` shows a single difference:
  `spec.replicas: 3 (desired) vs 7 (live)` on Deployment capstone-api.
- The HPA `capstone-api` is reporting `targetCPU 70%`, current replicas 7.
- Load test is running in dev since this morning; CPU is at ~85%.
- Every 3 minutes: Application flips Synced -> OutOfSync -> Synced; pods are
  terminated and recreated. On-call is annoyed.

What is Argo CD doing wrong operationally?
MD

cat > "$BASE/scenario-b/report.md" <<'MD'
# Report — Scenario B

## Causa raíz (una línea)
TODO: en una línea, qué causó el OutOfSync.

## Corrección mínima aplicada
- TODO: qué cambiaste y por qué.

## Riesgo si no se corrige
TODO: qué puede ir mal si se deja así.
MD

############################################
# SCENARIO C — manual kubectl edit
############################################
cat > "$BASE/scenario-c/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capstone-worker-stg
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/acme/capstone-infra.git
    path: envs/stg/worker
    targetRevision: release/stg
  destination:
    server: https://kubernetes.default.svc
    namespace: capstone-stg
  syncPolicy: {}        # manual sync in stg
YAML

cat > "$BASE/scenario-c/desired-in-git.yaml" <<'YAML'
# What the repo says.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-worker
  namespace: capstone-stg
spec:
  replicas: 2
  selector:
    matchLabels: { app: capstone-worker }
  template:
    metadata:
      labels: { app: capstone-worker }
    spec:
      containers:
        - name: worker
          image: ghcr.io/acme/capstone-worker:v1.4.2
          env:
            - name: LOG_LEVEL
              value: info
YAML

cat > "$BASE/scenario-c/live-in-cluster.yaml" <<'YAML'
# What is actually running.
# Yesterday an on-call engineer did:
#   kubectl -n capstone-stg set env deploy/capstone-worker LOG_LEVEL=debug
# to debug an incident. The incident is now closed; the change was useful and
# should be kept.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-worker
  namespace: capstone-stg
spec:
  replicas: 2
  selector:
    matchLabels: { app: capstone-worker }
  template:
    metadata:
      labels: { app: capstone-worker }
    spec:
      containers:
        - name: worker
          image: ghcr.io/acme/capstone-worker:v1.4.2
          env:
            - name: LOG_LEVEL
              value: debug
YAML

cat > "$BASE/scenario-c/evidence.md" <<'MD'
# Scenario C — operational evidence

- `argocd app diff capstone-worker-stg` shows exactly one line:
  `env.LOG_LEVEL: info (desired) -> debug (live)`.
- `kubectl get events -n capstone-stg` shows a `set env` performed by user
  `alice` yesterday 22:14 UTC.
- Incident #4812 is closed; alice confirms the extra verbosity helped diagnose
  the issue and should remain, as the team agreed to make it the default in stg.
- Argo CD is NOT auto-syncing (syncPolicy is manual in stg).
- Right now, if someone clicks "Sync" in the UI, LOG_LEVEL goes back to `info`.

What should you do before anyone clicks Sync?
MD

cat > "$BASE/scenario-c/report.md" <<'MD'
# Report — Scenario C

## Causa raíz (una línea)
TODO: en una línea, qué causó el OutOfSync.

## Decisión: promover a Git o revertir en cluster
TODO: elige y justifica (una o dos líneas).

## Corrección mínima aplicada
- TODO: qué archivo tocaste y por qué.

## Riesgo si no se corrige
TODO: qué puede ir mal si se deja así.
MD

echo "Done. Scenarios ready under $BASE"
ls -la "$BASE"
