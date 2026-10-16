# Solution notes — argo-06-01

## Why these choices

- `sourceRepos` pinned to the example-apps repo: in a real org, you'd pin to the team's own manifest repo. The point is **never `*`**.
- `destinations.namespace: payments-*` (or `checkout-*`): a glob keeps multiple envs (dev/stg/prod) under one project without opening the whole cluster.
- `clusterResourceWhitelist`:
  - `team-payments` keeps `Namespace` because the Application uses `CreateNamespace=true`.
  - `team-checkout` has it empty on purpose — Platform provisions namespaces for them. A deliberate asymmetry to show both patterns.
- `namespaceResourceBlacklist` on `team-payments` forbids `ResourceQuota`/`LimitRange`: Platform owns capacity policy for everyone.

## Why `checkout-crossing` is rejected

- Its `destination.namespace` is `payments-prod`.
- `team-checkout.destinations` only allows `checkout-*`.
- The Argo CD application-controller fills `.status.conditions[]` with an `InvalidSpecError` whose message contains `is not permitted in project 'team-checkout'`.

The Application resource itself is created in `argocd` (the apiserver doesn't block it); it just never reconciles into the target cluster.

## Observing it live

```bash
argocd app get checkout-crossing
# or
kubectl -n argocd get application checkout-crossing -o yaml
```
