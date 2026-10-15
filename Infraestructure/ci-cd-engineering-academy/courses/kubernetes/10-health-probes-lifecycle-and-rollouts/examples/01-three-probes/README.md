# Ejemplo 01 — Las tres probes bien separadas

Demuestra un Deployment con `startupProbe`, `readinessProbe` y `livenessProbe` **correctamente** diferenciadas sobre una imagen de nginx.

## Qué muestra

- `startupProbe` cubre el arranque (hasta 300 s) y suspende las otras dos.
- `readinessProbe` apunta a `/` y controla la pertenencia al Service — si falla, el Pod sale de Endpoints sin morir.
- `livenessProbe` apunta a `/` también pero con `periodSeconds` alto y `failureThreshold` conservador — mata solo si el proceso realmente está colgado.

En una app real `/healthz` y `/readyz` serían endpoints distintos. Aquí usamos nginx estándar para no pedir una imagen custom; el *patrón* es lo que importa.

## Requisitos

- Cluster local (kind, k3d, minikube). Ver módulo `k8s-02`.
- `kubectl` configurado contra ese cluster.

## Cómo correrlo

```bash
mkdir -p /tmp/k8s-10-ex01 && cd /tmp/k8s-10-ex01
cp "$OLDPWD/manifest.yaml" .   # o copia desde donde estés

kubectl apply -f manifest.yaml
kubectl rollout status deployment/three-probes-demo --timeout=120s

# Observa cómo arranca: el startupProbe pasa primero, luego las otras se activan
kubectl get pods -l app=three-probes-demo -o wide
kubectl describe pod -l app=three-probes-demo | grep -E "Liveness|Readiness|Startup"

# Prueba el Service
kubectl port-forward svc/three-probes-demo 18080:80 &
sleep 2
curl -sS -o /dev/null -w "status=%{http_code}\n" http://localhost:18080/
kill %1 2>/dev/null || true
```

## Qué observar

```bash
kubectl describe pod -l app=three-probes-demo
```

Fíjate en los eventos: verás `Startup probe succeeded` **antes** de que aparezca el primer evento de `Readiness` o `Liveness`.

## Limpieza

```bash
kubectl delete -f manifest.yaml
rm -rf /tmp/k8s-10-ex01
```
