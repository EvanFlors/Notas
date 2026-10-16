# Solution — argo-08-02

The `starter/bootstrap.sh` script already materializes the full target state (that's the
nature of a bootstrap lab — the "solution" is the layout it emits + the two guardrails).
Rather than duplicate files here, this folder documents **what to check against your own
attempt** if you built the layout from scratch.

## The seven decisions baked into the solution

1. **Root is an ApplicationSet with a Git generator over `addons/*` and `apps/*`.**
   Alternative (app-of-apps) is valid but requires one Application per folder — more
   boilerplate.

2. **`addons/argo-cd/application.yaml` has `selfHeal: false` AND `prune: false`.**
   Non-negotiable. Theory section 5 explains why. Any other combination is a chicken-and-egg
   trap.

3. **Everything else has `selfHeal: true` and `prune: true`.** We want drift-free add-ons.

4. **`ServerSideApply=true`** across the board — CRDs in the Argo chart are huge and
   trigger `metadata.annotations: Too long` with client-side apply.

5. **`CreateNamespace=true`** so the first apply creates the target namespaces.

6. **Spoke registered declaratively** with the `argocd.argoproj.io/secret-type: cluster`
   label; the Secret is produced *after* building the SA on the spoke and resolving the
   container IP of the spoke's control-plane node (not 127.0.0.1).

7. **The `file://` repo is a real git repo** (`git init` + initial commit) so Argo CD's
   git source works offline. Otherwise `repo-server` returns "not a git repository".

## If `validate.sh` fails on your attempt

- `root.yaml is not an ApplicationSet` — you probably wrote a plain Application pointing
  at `addons/` with `directory.recurse: true` (the app-of-apps pattern). That's fine
  conceptually, but this lab verifies the ApplicationSet layout; adjust accordingly.
- `argo-cd Application missing guardrails` — likely you forgot one of `selfHeal: false`
  or `prune: false`. Both are required.
- `no cluster Secret` — the spoke registration step failed. Common cause: Docker not
  running, kind spoke not reachable from `docker inspect` (unusual on Linux/macOS
  Docker Desktop).

## Reset and retry

```bash
cd ../starter
./cleanup.sh
./bootstrap.sh
```
