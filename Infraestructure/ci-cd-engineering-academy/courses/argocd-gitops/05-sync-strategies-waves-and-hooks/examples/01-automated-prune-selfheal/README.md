# Example 01 — Automated sync con prune y selfHeal

Manifest de `Application` canónico para un entorno **dev**: Argo CD sincroniza automáticamente, borra lo que desaparece del repo, y revierte cambios manuales en el cluster.

## Qué demuestra

- `syncPolicy.automated.prune: true` — eliminar un recurso del repo → eliminarlo del cluster.
- `syncPolicy.automated.selfHeal: true` — `kubectl edit` manual → revertido automáticamente.
- `syncOptions` recomendadas: `CreateNamespace=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`.
- `retry` con backoff exponencial para tolerar fallos transitorios.

## Archivos

- `application.yaml` — la `Application` de Argo CD.
- `app/` — manifests que la `Application` referencia (en producción vivirían en un repo Git; aquí son muestra).

## Probar en kind + Argo CD (opcional)

Requiere Argo CD instalado en el cluster (ver `argo-02`). Si quieres hacer end-to-end:

```sh
# 1) Publica el directorio app/ en un repo Git accesible por Argo CD y
#    ajusta spec.source.repoURL/path/targetRevision en application.yaml.
# 2) kubectl apply -n argocd -f application.yaml
# 3) kubectl -n argocd get application dev-demo -w
```

Para probar `selfHeal`:

```sh
kubectl -n dev-demo scale deploy/web --replicas=10
# A los pocos segundos, Argo CD la devuelve a lo que diga el manifest del repo.
```

Para probar `prune`:

```sh
# Elimina deployment.yaml del repo, haz commit y push.
# Argo CD borra el Deployment del cluster en el próximo reconcile.
```

## Trampas

- Si publicas los manifests sin `Namespace`, necesitas `CreateNamespace=true` o un `Namespace` previo. Si lo quitas por error del repo y tienes `prune: true`, Argo CD intentará borrar el `Namespace` — con todos los recursos dentro. Pensar bien quién "posee" el `Namespace`.
- `selfHeal: true` es poderoso. En producción, en lugar de activarlo, considera `syncPolicy` manual + sync windows (ver `examples/02`).
