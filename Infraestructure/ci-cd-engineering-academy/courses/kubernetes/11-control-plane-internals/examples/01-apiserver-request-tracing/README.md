# Ejemplo 01 — Tracing de requests al `kube-apiserver` con `kubectl -v=9`

## Concepto que demuestra

Ver, con los ojos propios, cada llamada HTTP que `kubectl` hace contra el apiserver: GETs al `/openapi/v3`, POSTs con el objeto serializado, WATCHes long-poll. Hace tangible la cadena de la sección 2 y 11 de la lección.

## Plataforma

Linux o macOS, con `kind` + `kubectl` + `docker`. Si no tienes `kind`, los comandos son los mismos contra cualquier cluster (k3d, minikube, EKS, etc.).

## Prerrequisitos

- `kubectl` ≥ 1.28.
- Un cluster accesible (`kubectl cluster-info`).
- Opcional: `kind` para levantar uno local (`brew install kind`).

## Ejecución

### 1. Levantar cluster local (si no tienes uno)

```bash
kind create cluster --name k8s11
kubectl config use-context kind-k8s11
kubectl get nodes
```

### 2. Observar un `GET` simple

`-v=9` imprime la petición HTTP, headers, body de request y de respuesta.

```bash
kubectl -v=9 get pods -n kube-system 2>&1 | head -60
```

Qué buscar en el output:

- `GET https://127.0.0.1:<port>/api/v1/namespaces/kube-system/pods?limit=500` — URL exacta.
- `Request Headers:` incluye `Authorization: Bearer <token>` o `Content-Type`.
- `Response Status: 200 OK in <ms> milliseconds` — latencia real.
- `Response Body:` JSON crudo con los Pods.

### 3. Observar un `POST` (apply)

```bash
cat > /tmp/k8s11-nginx.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tracing-demo
  namespace: default
  labels: { app: tracing-demo }
spec:
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports: [{ containerPort: 80 }]
EOF

kubectl -v=9 apply -f /tmp/k8s11-nginx.yaml 2>&1 | tee /tmp/k8s11-apply.log | grep -E "POST|PATCH|Response Status" | head -20
```

En `server-side apply` (default moderno) verás un `PATCH` con `Content-Type: application/apply-patch+yaml`. En `--validate=false` o versiones viejas, un `POST` directo.

### 4. Observar un `WATCH` (long-poll)

```bash
# En otra terminal: provoca cambios
kubectl label pod tracing-demo refreshed=true --overwrite &

# Mientras tanto, un watch verboso
timeout 10 kubectl -v=9 get pods -w 2>&1 | grep -E "watch=true|RESPONSE|added|modified" | head -20
```

Observa el parámetro `watch=true&resourceVersion=<N>`. El apiserver no cierra la conexión; envía eventos conforme ocurren (chunked transfer encoding).

### 5. Qué registra el audit log

Si tu cluster tiene audit habilitado (en `kind` por defecto **no**), cada una de las requests de arriba genera una entrada JSON en el audit log con `verb`, `user`, `objectRef`, `responseStatus`. En la actividad 02 del módulo `k8s-17` lo activarás.

## Limpieza

```bash
kubectl delete pod tracing-demo --ignore-not-found
rm -f /tmp/k8s11-nginx.yaml /tmp/k8s11-apply.log
# opcional: kind delete cluster --name k8s11
```

## Lo que deberías notar

- Un simple `kubectl get` son **2+ HTTP calls** (descubrimiento + list).
- El cliente **no** reconstruye el objeto: lo descarga tal como vino del apiserver.
- `apply` server-side envía un **patch**, no un `POST`; el server mantiene `managedFields` para saber quién tocó qué.
- Los WATCHes son **HTTP long-poll**: una conexión persistente que el apiserver mantiene abierta y por la que envía eventos.
