# Ejemplo 01 — Blue/green con `activeService` + `previewService`

Un `Rollout` blue/green que mantiene dos Services: uno sirve el tráfico de producción (`active`), otro expone la versión nueva para smoke/QA (`preview`). Promoción manual.

## Qué muestra

- Cómo definir un `Rollout` con `strategy.blueGreen`.
- El switch atómico de Service (`activeService`) al promover.
- `scaleDownDelaySeconds` para rollback caliente.
- `autoPromotionEnabled: false` + `kubectl argo rollouts promote`.

## Requisitos

- Cluster local (kind, k3d, minikube).
- **Argo Rollouts instalado** en el namespace `argo-rollouts`.
- Plugin CLI opcional: `kubectl argo rollouts`.

Si no tienes nada todavía:

```bash
kind create cluster --name argo-rollouts-demo
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=120s
```

## Cómo correrlo

```bash
mkdir -p /tmp/argo-10-ex01 && cd /tmp/argo-10-ex01
# Copia los manifests desde el repo:
# cp <repo>/courses/argocd-gitops/10-.../examples/01-blue-green-with-services/*.yaml .

kubectl apply -f rollout.yaml
kubectl apply -f services.yaml

# Observa el Rollout (requiere plugin):
kubectl argo rollouts get rollout bg-demo --watch &
# Alternativa sin plugin:
# kubectl get rollout bg-demo -o yaml | grep -A2 status

# Expón el active:
kubectl port-forward svc/bg-demo-active 18081:80 &
sleep 2
curl -sS http://localhost:18081/ | head -3

# Dispara un rollout cambiando la imagen (de nginx:1.25 a nginx:1.27):
kubectl patch rollout bg-demo --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"nginx:1.27"}]}}}}'

# El Rollout se queda en Paused tras escalar el preview; smoke test contra preview:
kubectl port-forward svc/bg-demo-preview 18082:80 &
sleep 2
curl -sS http://localhost:18082/ | head -3

# Promueve:
kubectl argo rollouts promote bg-demo
# o, GitOps-puro, anotando (equivalente):
# kubectl annotate rollout bg-demo rollout.argoproj.io/promote-full=true

kubectl argo rollouts status bg-demo --timeout 2m
```

## Qué observar

- Tras `patch`, aparece un segundo `ReplicaSet` (`kubectl get rs -l app=bg-demo`).
- El `active` sigue sirviendo el viejo hasta que promueves.
- Tras promover: el `active` repunta al nuevo (switch de Service, ms); el viejo queda `scaleDownDelaySeconds: 60` por si abort.

## Limpieza

```bash
kill %1 %2 2>/dev/null || true
kubectl delete -f services.yaml --ignore-not-found
kubectl delete -f rollout.yaml --ignore-not-found
rm -rf /tmp/argo-10-ex01
```

Si creaste el cluster sólo para esto:

```bash
kind delete cluster --name argo-rollouts-demo
```
