# Ejemplo 03 — Resolución CoreDNS desde un Pod cliente

## Concepto que demuestra

- Cómo `/etc/resolv.conf` del Pod apunta a **CoreDNS**.
- Formato FQDN `<svc>.<ns>.svc.cluster.local`.
- Nombre corto (mismo namespace) y nombre `svc.ns` (otro namespace).
- Resolución de un Service `ExternalName` (CNAME puro).

## Prerrequisitos

- Un cluster `kind` activo. Puedes reutilizar el del ejemplo 01 o levantar uno nuevo.
- `kubectl` apuntando a ese cluster.

## Ejecución

```bash
mkdir -p /tmp/k8s-04-ex03 && cd /tmp/k8s-04-ex03

kind delete cluster --name k8s04-ex3 >/dev/null 2>&1 || true
kind create cluster --name k8s04-ex3 --wait 90s
kubectl config use-context kind-k8s04-ex3

# 1) Dos namespaces y una app en cada uno.
kubectl create namespace team-a
kubectl create namespace team-b

cat > apps.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, namespace: team-a }
spec:
  replicas: 1
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports: [{ containerPort: 80 }]
---
apiVersion: v1
kind: Service
metadata: { name: api, namespace: team-a }
spec:
  selector: { app: api }
  ports: [{ port: 80, targetPort: 80 }]
---
# ExternalName: puente DNS puro a un hostname externo.
apiVersion: v1
kind: Service
metadata: { name: upstream, namespace: team-b }
spec:
  type: ExternalName
  externalName: example.com
YAML

kubectl apply -f apps.yaml
kubectl -n team-a rollout status deploy/api --timeout=60s
```

Ahora un Pod cliente **en team-b** que resuelva nombres:

```bash
kubectl -n team-b run dns \
  --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 \
  --restart=Never -- sleep 3600
kubectl -n team-b wait --for=condition=Ready pod/dns --timeout=60s

# 2) Mira el resolv.conf del Pod.
kubectl -n team-b exec dns -- cat /etc/resolv.conf
#   Esperado:
#     nameserver 10.96.0.10
#     search team-b.svc.cluster.local svc.cluster.local cluster.local
#     options ndots:5

# 3) Nombre corto: NO funciona desde otro namespace, falla.
kubectl -n team-b exec dns -- nslookup api 2>&1 | tail -5 || true
#   api se intenta como "api.team-b.svc.cluster.local" → NXDOMAIN.

# 4) <svc>.<ns>: funciona (CoreDNS completa el sufijo).
kubectl -n team-b exec dns -- nslookup api.team-a
#   Devuelve el ClusterIP del Service "api" en el namespace team-a.

# 5) FQDN completo: siempre funciona.
kubectl -n team-b exec dns -- nslookup api.team-a.svc.cluster.local

# 6) ExternalName: CNAME puro.
kubectl -n team-b exec dns -- nslookup upstream.team-b.svc.cluster.local
#   Devuelve el CNAME → example.com → sus A-records reales.
```

## Resultado esperado

- `resolv.conf` apunta a `10.96.0.10` (ClusterIP de CoreDNS) y lista los 3 sufijos de `search`.
- `nslookup api` **falla** (nombre corto no cruza namespace).
- `nslookup api.team-a` y `nslookup api.team-a.svc.cluster.local` **funcionan** y devuelven el VIP del Service.
- `nslookup upstream.team-b.svc.cluster.local` devuelve `example.com` como CNAME.

## Preguntas de reflexión

1. ¿Qué significa `options ndots:5`? ¿Por qué un nombre con 5+ puntos se resuelve "literal" primero?
2. Si borras CoreDNS (`kubectl -n kube-system delete deploy coredns`), ¿qué pasa con los Pods nuevos? ¿Y con los Pods existentes que ya tienen conexiones establecidas?
3. ¿Por qué `ExternalName` **no** aparece en `kubectl get endpoints` cuando lo listas? (Pista: no tiene backends ni VIP; es solo DNS.)

## Limpieza

```bash
kind delete cluster --name k8s04-ex3
rm -rf /tmp/k8s-04-ex03
```
