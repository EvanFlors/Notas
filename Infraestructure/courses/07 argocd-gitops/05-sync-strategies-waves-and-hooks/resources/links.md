# Recursos — argo-05

## Documentación oficial Argo CD

- Sync options — https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- Auto-sync (automated) — https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- Sync waves — https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- Resource hooks — https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/
- Diffing customization y `ignoreDifferences` — https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/
- Sync windows (en `AppProject`) — https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/
- `argocd app sync` reference — https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_sync/

## Kubernetes relacionado

- Server-Side Apply — https://kubernetes.io/docs/reference/using-api/server-side-apply/
- Jobs — https://kubernetes.io/docs/concepts/workloads/controllers/job/
- Init containers (contraste con hooks) — https://kubernetes.io/docs/concepts/workloads/pods/init-containers/

## Patrones y discusión

- "Why Helm hooks don't run under Argo CD" — https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#helm-hooks
- Progressive sync en ApplicationSet (contraste con sync waves intra-Application) — https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/
- Codefresh blog "Argo CD sync waves and hooks" — https://codefresh.io/learn/argo-cd/

## Lectura complementaria

- OpenGitOps principles — https://opengitops.dev
- Akuity blog (mantenedores de Argo CD) — https://akuity.io/blog
- Discusión en GitHub sobre `selfHeal` en producción — buscar en `argoproj/argo-cd` issues con label `question`.
