# Ejemplo 02 — Cluster generator (fleet)

Una `Application` por **cluster registrado** en Argo CD. Útil para desplegar el mismo add-on (ingress, cert-manager, Prometheus) en toda la flota.

## Prerequisito

Tener ≥1 cluster registrado además del in-cluster. Se registra con:

```bash
argocd cluster add <kube-context-name>
```

O declarativamente creando un `Secret` con `argocd.argoproj.io/secret-type: cluster` y las labels que luego filtrarás.

## Manifest

Ver `appset.yaml`. Puntos:

- Filtro `selector.matchLabels.env: prod` — sólo clusters prod reciben la App.
- `{{.name}}` y `{{.server}}` provienen del Secret del cluster.
- El `source` es un chart Helm común a todos.
- Nombre `prom-{{.name}}` evita colisiones.

## Qué pasa cuando añades un cluster

Si registras `prod-apac` con `env: prod`, en el siguiente poll aparece `prom-prod-apac`. Sin tocar nada más.

## Trampa: in-cluster

El cluster "in-cluster" (`https://kubernetes.default.svc`) **también** es un cluster registrado y puede matchear si tiene las labels. Normalmente **no quieres** desplegar el add-on sobre el cluster de Argo CD mismo. Si es un cluster-plane dedicado, exclúyelo con un selector adicional (`matchExpressions: [{key: name, operator: NotIn, values: [in-cluster]}]`).
