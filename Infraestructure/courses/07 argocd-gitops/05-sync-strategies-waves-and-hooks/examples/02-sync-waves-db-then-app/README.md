# Example 02 — Sync waves: BD antes que la app

Tres recursos ordenados con `argocd.argoproj.io/sync-wave`:

- `Namespace` — wave `-20`.
- `StatefulSet` simulando una BD (postgres image, 1 replica) — wave `-10`.
- `Deployment` de la "app" que depende de la BD + su `Service` — wave `0`.
- `Ingress` ficticio — wave `10`.

Argo CD aplica cada wave y espera a `Healthy` antes de pasar a la siguiente. El `Deployment` **no** arranca hasta que la BD reporte `Ready`.

## Archivos

- `application.yaml` — Application que apunta a `app/`.
- `app/` — manifests con las anotaciones de wave.

## Probar

Requiere Argo CD en el cluster.

```sh
kubectl apply -f application.yaml
kubectl -n argocd get application waves-demo -w
kubectl -n waves-demo get pods -w
```

Observarás el orden: `Namespace` → `StatefulSet` creado y pod `Running` → `Deployment` pods creados → `Ingress`.

## Trampas

- Si el `StatefulSet` nunca llega a `Healthy` (p. ej. `PersistentVolumeClaim` sin provisioner), Argo CD se queda bloqueado en wave `-10` indefinidamente. Debugear con `argocd app get waves-demo` y revisar el pod.
- Sync waves ordenan DENTRO de la Application. Si BD y app están en Applications distintas, usar `App-of-Apps` con sync wave en los Application padres (ver `argo-07`).
- No olvidar que `kind: StatefulSet` ordena *después* de `Deployment` en el orden canónico de kinds — por eso aquí usamos sync-wave explícito.
