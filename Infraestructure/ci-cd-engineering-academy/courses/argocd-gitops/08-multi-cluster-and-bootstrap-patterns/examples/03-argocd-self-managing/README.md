# Example 03 — Argo CD self-managing

> **Goal:** make Argo CD manage its own installation via GitOps while keeping safe
> guard-rails against the chicken-and-egg trap.

## The Application

`application.yaml` defines an `Application` named `argo-cd` that points to the official
Argo Helm chart. Key choices and *why*:

| Field                                | Value         | Why |
|--------------------------------------|---------------|-----|
| `automated.selfHeal`                 | `false`       | A bad commit should *not* auto-rollback the controller; humans trigger sync. |
| `automated.prune`                    | `false`       | Never delete argocd resources via GitOps — too easy to break. |
| `syncOptions: ServerSideApply=true`  | enabled       | CRDs in the chart are huge; SSA avoids `metadata.annotations: Too long` on refresh. |
| `syncOptions: RespectIgnoreDifferences=true` | enabled | Lets `ignoreDifferences` win even during initial apply. |
| `annotations: sync-wave=-100`        | enabled       | This Application reconciles first within a bootstrap wave. |
| `ignoreDifferences` on Deployment `/spec/replicas` | enabled | Permits HPA (if ever added) without perpetual OutOfSync. |

## Expected flow

1. **First time (imperative install)** — operator applies upstream manifests to install
   Argo CD by hand. See `bootstrap-install.sh`.
2. **Second step** — operator applies `application.yaml`. Argo CD discovers its own
   Deployment, StatefulSet, CRDs, Services, and marks itself `Synced + Healthy`.
3. **From now on** — any upgrade is a PR that bumps `targetRevision` in the Helm source.
   A human triggers `argocd app sync argo-cd` (not auto).

## Recovering from a bad upgrade

If a bump leaves the controller crashlooping:

```bash
# Re-apply the last-known-good upstream manifests imperatively
kubectl -n argocd apply -k \
  "https://raw.githubusercontent.com/argoproj/argo-cd/<KNOWN_GOOD_TAG>/manifests/"

# Fix the Application to point to the known-good chart version
kubectl -n argocd edit application argo-cd    # revert targetRevision

# Trigger sync
argocd app sync argo-cd
```

See `theory/lesson.md` section 5 for the full recovery narrative.

## Why NOT just use selfHeal

With `selfHeal: true`, Argo CD immediately reapplies whatever Git says. If Git says
"deploy argocd:broken-tag", you get a crashloop that cannot be stopped from GitOps
(there's no reconciler left). `selfHeal: false` forces the upgrade to be a *deliberate*
act — the small loss in automation buys back a critical safety margin.
