# Example 03 — Atomic upgrade con rollback automático

Chart diseñado para demostrar `--atomic`: tiene un flag `broken` que, al ser `true`, apunta a una imagen inexistente. Un upgrade con esa flag debería fallar y, con `--atomic`, retroceder a la revisión previa.

## Walkthrough

```sh
# 1) Install limpio (revision 1)
helm install atomic . --namespace atomic --create-namespace \
  --atomic --timeout 2m

helm list --namespace atomic
helm history atomic --namespace atomic
# → 1 revision, status: deployed

# 2) Upgrade "malo" con --atomic → debe fallar y hacer rollback automático
helm upgrade atomic . --namespace atomic \
  --set broken=true \
  --atomic --timeout 60s
# → el comando retorna != 0

# 3) Verificar que el cluster quedó en la revisión previa
helm history atomic --namespace atomic
# → verás un rollback automático a la revisión 1
kubectl -n atomic get pods
# → el nginx original sigue corriendo
```

## Comparación: upgrade sin --atomic

Si lo mismo se hiciera sin `--atomic`:

```sh
helm upgrade atomic . --namespace atomic --set broken=true --timeout 60s
```

El comando igual retorna != 0, pero el `Deployment` se queda con la imagen rota (nuevos ReplicaSets con pods en `ErrImagePull`). El cluster termina en un estado parcial que requiere intervención manual.

## Nota sobre Helm 4

A partir de Helm 4, el flag `--atomic` emite un warning de deprecación y recomienda `--rollback-on-failure`. Ambos aceptan la misma semántica. En este curso usamos `--atomic` por continuidad con la literatura y porque sigue funcionando; en pipelines nuevos puedes preferir el nombre nuevo.

## En CI/CD

Patrón recomendado para pipelines:

```sh
helm upgrade --install myapp ./chart \
  --namespace prod --create-namespace \
  --atomic \
  --wait \
  --timeout 5m \
  --cleanup-on-fail \
  --values values-prod.yaml
```

- `--install` lo hace idempotente (crea el release si no existe).
- `--atomic` fuerza rollback en fallo.
- `--cleanup-on-fail` elimina recursos nuevos que no alcanzaron a estabilizarse.
- `--timeout` acota la ventana (ajustar al SLO del rollout de la app).

## Limpieza

```sh
helm uninstall atomic --namespace atomic
kubectl delete namespace atomic
```
