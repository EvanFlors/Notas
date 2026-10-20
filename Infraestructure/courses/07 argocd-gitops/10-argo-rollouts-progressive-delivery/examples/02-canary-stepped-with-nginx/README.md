# Ejemplo 02 — Canary con pasos (`setWeight` + `pause`)

Un `Rollout` canary de 4 pasos: 20% → pause 1m → 50% → pause indefinido → 100%. Sin traffic management (replica-based), por lo que el peso se aproxima por réplicas.

Incluye además un fragmento opcional con `trafficRouting.nginx` por si tienes `ingress-nginx` instalado — en ese modo el peso lo hace el proxy, no las réplicas.

## Qué muestra

- `strategy.canary.steps` con `setWeight`, `pause: {duration}`, `pause: {}`.
- Diferencia entre promoción temporizada (`duration`) y manual (`pause: {}` → `promote`).
- Cómo observar la progresión con el plugin.

## Requisitos

- Cluster local + Argo Rollouts instalado (ver `../01-blue-green-with-services/README.md`).
- Opcional: `ingress-nginx` para probar el modo traffic-routing.

## Cómo correrlo

```bash
mkdir -p /tmp/argo-10-ex02 && cd /tmp/argo-10-ex02
# cp <repo>/.../examples/02-canary-stepped-with-nginx/*.yaml .

kubectl apply -f rollout.yaml
kubectl apply -f service.yaml

kubectl argo rollouts get rollout canary-demo --watch &

# Dispara un rollout:
kubectl patch rollout canary-demo --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"nginx:1.27"}]}}}}'

# Verás: step 0 setWeight 20 → pause 1m → step 2 setWeight 50 → pause (manual)
# En el pause manual:
kubectl argo rollouts promote canary-demo

kubectl argo rollouts status canary-demo --timeout 5m
```

## Con ingress-nginx (opcional)

Si tienes ingress-nginx instalado, aplica `rollout-with-nginx.yaml` en vez de `rollout.yaml` y añade `ingress.yaml`. En ese modo:

- Se mantienen `canaryService` y `stableService` separados (selectores especiales con `rollouts-pod-template-hash`).
- El controller gestiona un Ingress hermano con `canary: "true"` + `canary-weight`.
- Con 2 réplicas puedes decir `setWeight: 1` sin problema (es peso de requests, no de pods).

## Qué observar

```bash
kubectl get rs -l app=canary-demo
# Verás 2 RS en los pasos intermedios.
kubectl describe rollout canary-demo | sed -n '/Steps:/,/Conditions:/p'
```

## Limpieza

```bash
kill %1 2>/dev/null || true
kubectl delete -f service.yaml --ignore-not-found
kubectl delete -f rollout.yaml --ignore-not-found
# si usaste nginx variant:
# kubectl delete -f ingress.yaml --ignore-not-found
# kubectl delete -f rollout-with-nginx.yaml --ignore-not-found
rm -rf /tmp/argo-10-ex02
```
