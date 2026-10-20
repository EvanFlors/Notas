# Ejemplo 01 — Pod bare vs Pod gestionado por Deployment

## Concepto que demuestra

La diferencia observable entre crear un **Pod directamente** y crear el **mismo Pod a través de un Deployment**: qué pasa cuando lo borras, qué pasa si crashea, y por qué el segundo es "la forma Kubernetes".

## Contexto

Es el ejercicio canónico para fijar en el cuerpo la idea de **reconciliation loop**. Un Pod bare es un objeto "muerto": si lo borras, no vuelve. Un Pod gestionado por un controller es un objeto "autoregenerativo": el controller lo vigila y lo reemplaza.

## Objetivo

Al terminar sabrás:

- Observar que `kubectl delete pod <nombre>` sobre un Pod bare es definitivo.
- Observar que el mismo `delete` sobre un Pod de un Deployment dispara una recreación en segundos.
- Leer `kubectl get rs` y entender quién es el "dueño" de los Pods.

## Prerrequisitos

- Cluster local kind o k3d corriendo (`kubectl cluster-info` responde).
- Namespace `default` disponible (o crea `demo` con `kubectl create ns demo` y añade `-n demo` a los comandos).

Si no tienes cluster: `kind create cluster --name k8s-03`.

## Ejecución

Copia-pega bloque a bloque. **Lee la salida antes de pasar al siguiente.**

```bash
# 0. Entorno limpio.
kubectl delete pod lonely --ignore-not-found
kubectl delete deployment hello --ignore-not-found

# 1. POD BARE: creado directo, sin controller.
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: lonely
  labels: { app: lonely }
spec:
  containers:
    - name: web
      image: nginxdemos/hello:plain-text
      ports: [{ containerPort: 80 }]
EOF

kubectl get pod lonely
# Espera a que esté Running:
kubectl wait --for=condition=Ready pod/lonely --timeout=120s

# 2. Bórralo. Observa: NO vuelve.
kubectl delete pod lonely
kubectl get pod lonely 2>&1 || echo ">>> lonely desapareció; nadie lo recrea <<<"

# 3. DEPLOYMENT: mismo template, pero envuelto en un controller.
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  labels: { app: hello }
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector:
    matchLabels: { app: hello }
  template:
    metadata:
      labels: { app: hello }
    spec:
      containers:
        - name: web
          image: nginxdemos/hello:plain-text
          ports: [{ containerPort: 80 }]
EOF

kubectl rollout status deployment/hello --timeout=120s

# 4. Mira la cadena Deployment → ReplicaSet → Pods.
kubectl get deploy,rs,pods -l app=hello
#   - 1 Deployment hello                  (dueño del RS)
#   - 1 ReplicaSet hello-<hash>           (dueño de los Pods)
#   - 3 Pods      hello-<hash>-<suffix>

# 5. ¿Quién es el dueño? Mira ownerReferences.
POD=$(kubectl get pod -l app=hello -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -o jsonpath='{.metadata.ownerReferences}' ; echo
#   Verás kind=ReplicaSet, apunta al RS por nombre.

RS=$(kubectl get rs -l app=hello -o jsonpath='{.items[0].metadata.name}')
kubectl get rs "$RS" -o jsonpath='{.metadata.ownerReferences}' ; echo
#   Verás kind=Deployment, apunta a "hello".

# 6. Borra un Pod gestionado. Observa: SÍ vuelve.
kubectl delete pod "$POD"
sleep 2
kubectl get pods -l app=hello
#   Siguen siendo 3; el que mataste fue reemplazado con otro nombre.

# 7. Borra el ReplicaSet (no el Deployment). Observa: el Deployment lo recrea.
RS=$(kubectl get rs -l app=hello -o jsonpath='{.items[0].metadata.name}')
kubectl delete rs "$RS"
sleep 3
kubectl get rs -l app=hello
#   El Deployment creó un nuevo RS. 3 Pods de vuelta.
```

## Resultado esperado

- Tras `kubectl delete pod lonely`, el Pod **no vuelve**: `kubectl get pod lonely` devuelve `NotFound`.
- Tras `kubectl delete pod <uno-de-hello>`, en 2–5 s hay otra vez 3 Pods bajo `app=hello`.
- `kubectl get pod -o jsonpath='{.metadata.ownerReferences}'` muestra `kind: ReplicaSet` para los Pods gestionados.
- Tras borrar el RS, el Deployment lo recrea solo.

## Limpieza

```bash
kubectl delete pod lonely --ignore-not-found
kubectl delete deployment hello --ignore-not-found
```

## Preguntas de reflexión

1. Si borras el **Deployment** `hello` con `kubectl delete deployment hello`, ¿qué pasa con el ReplicaSet y con los Pods? ¿Y si usas `--cascade=orphan`?
2. ¿Qué pasaría con `lonely` si el nodo donde corre muriera? ¿Y con los Pods de `hello`?
3. Si cambias el `restartPolicy` del template de `hello` a `Never`, ¿qué devuelve el apiserver al hacer `apply`? ¿Por qué?
4. ¿Qué información de `kubectl get pod -o yaml` te revela quién es el "padre" sin usar `--format`?
