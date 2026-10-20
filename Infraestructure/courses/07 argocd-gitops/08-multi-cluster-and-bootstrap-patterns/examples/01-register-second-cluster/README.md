# Example 01 — Register a second cluster

> **Goal:** take a working Argo CD "hub" and register a second cluster so it appears in
> `argocd cluster list`, using both the imperative and declarative paths.

Reads from `argo-02` (install) and `argo-07` (ApplicationSets).

## What you'll build

Two local kind clusters:

- `argo-hub` — Argo CD runs here (installed via upstream manifests).
- `argo-spoke` — empty target; registered to the hub.

Then one Application scoped to `spoke` demonstrates reconciliation across the hub boundary.

## Prerequisites

- Docker running.
- `kind` ≥ 0.20, `kubectl` ≥ 1.28.
- `argocd` CLI (optional — only needed for the imperative path).
- ~4 GB free RAM. **Skip** if your machine is tight.

## Files

- `kind-hub.yaml`, `kind-spoke.yaml` — minimal cluster configs.
- `install-argocd.sh` — installs upstream Argo CD on the hub.
- `register-spoke-declarative.sh` — creates the `argocd-manager` SA on the spoke, extracts
  a token, and renders a `Secret` manifest (`cluster-spoke.yaml`) that the hub applies.
- `register-spoke-cli.sh` — alternative using `argocd cluster add`.
- `cluster-spoke.yaml.tmpl` — template rendered by the declarative script.
- `demo-app.yaml` — Application that targets the spoke by `name: spoke`.
- `cleanup.sh` — tears down both kind clusters.

## Walkthrough

```bash
# 1) Spin up both clusters (idempotent)
kind create cluster --config kind-hub.yaml      --name argo-hub
kind create cluster --config kind-spoke.yaml    --name argo-spoke

# 2) Install Argo CD on the hub
kubectl --context kind-argo-hub create ns argocd || true
kubectl --context kind-argo-hub -n argocd apply \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl --context kind-argo-hub -n argocd rollout status deploy/argocd-server --timeout=180s

# 3) Register the spoke declaratively (preferred)
./register-spoke-declarative.sh
kubectl --context kind-argo-hub apply -f cluster-spoke.yaml

# 4) Confirm
kubectl --context kind-argo-hub -n argocd get secret -l argocd.argoproj.io/secret-type=cluster

# 5) Deploy the demo app on the spoke
kubectl --context kind-argo-hub apply -f demo-app.yaml
kubectl --context kind-argo-spoke -n default get deploy guestbook-ui -w
```

## Expected outcome

- `argocd-manager` SA + ClusterRoleBinding exist on the spoke.
- `cluster-spoke` Secret exists on the hub with the `cluster` label.
- The `demo-guestbook` Application in the hub reports `Synced + Healthy`, with its
  Deployment visible on the spoke (`kubectl --context kind-argo-spoke get deploy -A`).

## Clean up

```bash
./cleanup.sh
```

## Internals to notice

- The spoke's `argocd-manager` token is a `cluster-admin` credential — fine for a lab,
  **not** for production.
- The `server:` URL inside the Secret is the spoke API-server as reachable *from the hub
  Pod network*. With kind-on-kind that is `https://<spoke-container-ip>:6443`, not
  `127.0.0.1:xxxx` (which only works from your laptop). The script resolves this via
  `docker inspect`.
- `argocd cluster add` ends up producing the exact same Secret — it just does the token
  dance for you.
