# Ejemplo 02 — Headless Service + preview de StatefulSet

## Concepto que demuestra

- Un `Service` con `clusterIP: None` **no tiene VIP**: CoreDNS responde con los A-records de cada Pod.
- Un `StatefulSet` da **identidad por Pod** (`web-0`, `web-1`, `web-2`) y un DNS predecible por Pod cuando se asocia a un headless Service.
- Por eso bases de datos distribuidas (Postgres, Cassandra, Kafka) piden headless: cada Pod necesita ser direccionable individualmente.

> Nota: cubrimos StatefulSet a fondo en `k8s-06`. Aquí solo lo usamos para enseñar la primitiva **Headless**.

## Objetivo

- Crear un headless Service y verificar que `nslookup` devuelve **múltiples** IPs (una por Pod).
- Crear un StatefulSet mínimo y verificar que cada Pod tiene su propio DNS estable `<pod>.<svc>.<ns>.svc.cluster.local`.

## Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, Docker arriba.

## Ejecución

```bash
mkdir -p /tmp/k8s-04-ex02 && cd /tmp/k8s-04-ex02

kind delete cluster --name k8s04-ex2 >/dev/null 2>&1 || true
kind create cluster --name k8s04-ex2 --wait 90s
kubectl config use-context kind-k8s04-ex2
```

```bash
cat > headless.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None     # <-- headless
  selector:
    app: web
  ports:
    - port: 80
      name: http
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web    # <-- obligatorio: nombre del headless service
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
              name: http
YAML

kubectl apply -f headless.yaml
kubectl rollout status statefulset/web --timeout=90s
kubectl get pods -o wide
#   Fíjate en los nombres: web-0, web-1, web-2 (NO hashes aleatorios).
```

Observa que **no hay VIP**:

```bash
kubectl get svc web
#   CLUSTER-IP = None
```

Resuelve el Service y cada Pod individual:

```bash
kubectl run -i --rm --tty dns \
  --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 \
  --restart=Never -- bash

# Dentro del Pod cliente:
nslookup web.default.svc.cluster.local
# Esperado: 3 Address con las IPs de web-0/1/2.

nslookup web-0.web.default.svc.cluster.local
# Esperado: UNA IP (la de web-0).

nslookup web-1.web.default.svc.cluster.local
nslookup web-2.web.default.svc.cluster.local

exit
```

## Resultado esperado

- `kubectl get svc web` muestra `CLUSTER-IP = None`.
- `nslookup web.default.svc.cluster.local` devuelve **3 IPs**.
- `nslookup web-0.web.default.svc.cluster.local` devuelve **1 IP** (la del Pod `web-0`).

## Preguntas de reflexión

1. ¿Qué pasaría con un `curl http://web/` desde otro Pod? (Pista: no hay VIP; el cliente HTTP recibirá **una** de las IPs del DNS round-robin y hablará directo con ese Pod.)
2. ¿Por qué un cliente gRPC con "client-side load balancing" prefiere headless? ¿Qué información pierde si usa ClusterIP?
3. ¿Qué pasa si borras el StatefulSet con `kubectl delete sts web`? ¿Y los PVCs? (Spoiler: StatefulSet **no** borra PVCs; se cubre en k8s-06.)

## Limpieza

```bash
kind delete cluster --name k8s04-ex2
rm -rf /tmp/k8s-04-ex02
```
