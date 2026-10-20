# Ejemplo 03 — Pull Request generator (preview environments)

Crea un namespace de **preview** por cada PR abierto en un repo GitHub. Al cerrar el PR, el namespace y sus recursos desaparecen.

## Setup

Necesitas:

1. Token de GitHub con permiso `repo` almacenado como `Secret` en el namespace `argocd`:

```bash
kubectl -n argocd create secret generic github-token \
  --from-literal=token=ghp_xxxxxxxx
```

2. Un repo GitHub con PRs abiertos.

## Manifest

Ver `appset.yaml`. Puntos:

- `labels: ['preview']` → sólo PRs con esa label generan preview.
- `requeueAfterSeconds: 60` — polling frecuente para responder rápido (sin webhook).
- `destination.namespace: 'myapp-pr-{{.number}}'` → `myapp-pr-42`, `myapp-pr-57`.
- `targetRevision: '{{.head_sha}}'` → despliega **exactamente el commit** del PR, no la rama (immutable).
- `syncPolicy.preserveResourcesOnDeletion` NO está — al cerrar el PR, la App se borra y sus recursos también.

## Qué más necesitas en el repo

El `path` apuntado debe existir en el `head_sha` del PR y renderizar algo válido. Si usas Kustomize, haz que el namespace del overlay sea parametrizable con `namespace:` en el `kustomization.yaml`, o deja que Argo CD lo imponga vía `destination.namespace`.

## Trampa: colisión de recursos cluster-scoped

Si cada preview crea un `ClusterRoleBinding` con el mismo nombre, colisionan. Parametriza los recursos cluster-scoped con `-pr-{{.number}}` o evita crearlos en previews.

## Alternativa sin GitHub token

Para desarrollo local sin credenciales, puedes mockear PRs con un `list` generator cuyos elementos imiten el shape (`number`, `branch`, `head_sha`). Es exactamente lo que hace la actividad `02-pr-preview-environments`.
