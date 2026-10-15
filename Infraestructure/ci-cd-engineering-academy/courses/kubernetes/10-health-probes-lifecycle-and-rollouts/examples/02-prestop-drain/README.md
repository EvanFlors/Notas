# Ejemplo 02 — `preStop` + `terminationGracePeriodSeconds` para drenaje

Demuestra la ventana de carrera entre la remoción de endpoints y el cierre del proceso, y cómo un `preStop sleep` la absorbe.

## Qué muestra

Sin `preStop`:
- Al borrar un Pod, el kubelet manda `SIGTERM` inmediatamente.
- `kube-proxy` tarda ~100 ms – 2 s en reprogramar iptables.
- Un cliente que mande requests a esa IP durante esa ventana recibe `connection refused`.

Con `preStop: sleep 10` + `terminationGracePeriodSeconds: 40`:
- Al borrar el Pod, el kubelet corre `sleep 10` **antes** de `SIGTERM`.
- Durante esos 10 s el proceso sigue sirviendo, pero los endpoints ya se removieron.
- A los 10 s se manda `SIGTERM`; al proceso le quedan 30 s para cerrar limpio.
- El cliente no ve `connection refused`.

## Requisitos

- Cluster local.
- `kubectl` configurado.

## Cómo correrlo

```bash
mkdir -p /tmp/k8s-10-ex02 && cd /tmp/k8s-10-ex02

kubectl apply -f manifest.yaml
kubectl rollout status deployment/drain-demo --timeout=60s

# Load generator desde otro Pod
kubectl run loadgen --image=curlimages/curl:8.9.1 --restart=Never -- \
  sh -c 'while true; do curl -sS -o /dev/null -w "%{http_code} " http://drain-demo/; sleep 0.1; done'

# En otra terminal: observa el loop (debería ser todo 200)
kubectl logs -f pod/loadgen &
LF_PID=$!

# Dispara un rolling update tocando una env (fuerza nuevo RS)
kubectl set env deployment/drain-demo ROLL="$(date +%s)"

# Mientras rueda, observa que loadgen ve 200 constantemente (sin preStop verías 000/5xx)
sleep 30
kill $LF_PID 2>/dev/null || true
```

## Qué observar

- `kubectl get pods -w` — verás un Pod viejo en `Terminating` durante ~40 s mientras el nuevo entra ready.
- `kubectl logs loadgen` — una línea sin 000, 502, 503.

## Limpieza

```bash
kubectl delete pod loadgen --ignore-not-found
kubectl delete -f manifest.yaml
rm -rf /tmp/k8s-10-ex02
```
