# Ejemplo 01 — Git generator "env per folder"

Un `ApplicationSet` que descubre subdirectorios en `envs/*` de un repo y genera **una `Application` por entorno**. Es el patrón más adoptado y el que usarás en el capstone.

## Estructura asumida del repo de infra

```
envs/
├── dev/
│   └── kustomization.yaml  (o Chart.yaml / plain manifests)
├── stg/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

## Manifest

Ver `appset.yaml` en este directorio.

Puntos a observar:

- `goTemplate: true` + `missingkey=error`.
- Variable `{{.path.basename}}` → `dev`, `stg`, `prod`.
- `destination.namespace: 'myapp-{{.path.basename}}'` crea un namespace por ambiente.
- `syncPolicy.automated.selfHeal: true` sólo en `dev`/`stg` vía `templatePatch` sería más estricto; aquí se simplifica.
- `revision: HEAD` es cómodo para didáctica — en producción prefiere tag o commit para artefactos.

## Qué pasa si añades `envs/qa/`

El controller detecta un elemento nuevo en el siguiente poll (default: 3 min, configurable con `requeueAfterSeconds` o webhook) y crea `myapp-qa` sin cambios al `ApplicationSet` mismo.

## Qué pasa si borras `envs/dev/`

El controller **borra** la Application `myapp-dev` y, por default, **también** sus recursos en el cluster. Si no es lo que quieres, añade:

```yaml
syncPolicy:
  preserveResourcesOnDeletion: true
```

a nivel del `ApplicationSet.spec.syncPolicy` (no al template).

## Cómo probarlo (requiere kind + argocd + un repo)

```bash
kubectl apply -f appset.yaml
kubectl get applicationset -n argocd envs
kubectl get applications -n argocd -l generated-by=git-envs
```

Esperado: 3 Applications con nombres `myapp-dev`, `myapp-stg`, `myapp-prod`.
