# Solución de referencia — argo-07-01

El `appset.yaml` adjunto es una solución válida. Lo relevante:

- `goTemplate: true` + `missingkey=error`.
- Generator `git.directories` con `envs/*` + `exclude` de `_shared`.
- `{{.path.basename}}` para derivar el nombre y namespace.
- `syncPolicy.automated` con `prune` y `selfHeal`, y `CreateNamespace=true` para que Argo CD cree los namespaces target.

Para aplicarlo end-to-end necesitas Argo CD con `applicationset-controller` y que el `repo-server` tenga acceso al path `file:///tmp/argo-07-01/infra-repo` *desde dentro del pod*. En kind esto exige montar el directorio como `extraMounts`; en entornos reales se usa un repo remoto (GitHub, GitLab, un gitea in-cluster).

Alternativas igualmente correctas:

- Dividir en dos `git` generators (uno por path) en lugar de usar `exclude`.
- Añadir `strategy: RollingSync` para progresión controlada.
- Usar `templatePatch` para desactivar `selfHeal` sólo en `prod`.
