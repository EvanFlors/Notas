# Ejemplo 02 — Operaciones comunes de `kubectl`

## Concepto que demuestra

Las operaciones diarias sobre un workload: `get`, `describe`, `logs`, `exec`, `port-forward`, con comentarios sobre qué pide la CLI al apiserver en cada paso y qué estado consulta cuál.

## Contexto

Partimos de un cluster kind. Creamos un Pod ad-hoc (sin Deployment aún — eso llega en `k8s-03`) con `nginx:alpine`, lo exploramos con los verbos de lectura y lo exponemos vía `port-forward`.

## Objetivo

Al terminar sabrás:

- Qué diferencia hay entre `get` y `describe` (lo que ves y lo que no).
- Cómo seguir logs en vivo con `-f --tail`.
- Que `exec` es un proceso adicional, no una sesión SSH.
- Qué pasa físicamente con `port-forward` y por qué cae si cae el apiserver.

## Prerrequisitos

- Cluster kind arriba (usa el del `activities/01-create-local-cluster` o crea uno temporal).
- `kubectl` configurado al contexto correcto (`kubectl config current-context` debe decir `kind-...`).
- Puerto 8080 libre en el host.
- `curl`.

## Ejecución

```bash
# 0. Entorno limpio.
mkdir -p /tmp/k8s-02-ex02 && cd /tmp/k8s-02-ex02
kubectl delete pod web --ignore-not-found

# 1. Crear un Pod imperativamente (no es la "forma K8s" para producción,
#    pero sirve para explorar).
kubectl run web --image=nginx:alpine --port=80
#   POST /api/v1/namespaces/default/pods con un objeto Pod minimal.

# 2. GET: tabla por default.
kubectl get pod web
#   NAME   READY   STATUS    RESTARTS   AGE
#   web    1/1     Running   0          5s

kubectl get pod web -o wide
#   + IP interna + nodo donde corre.

# 3. Esperar a que esté Ready (útil en scripts).
kubectl wait --for=condition=Ready pod/web --timeout=60s

# 4. DESCRIBE: evento humano, útil para debugging.
kubectl describe pod web | head -40
#   Secciones: Metadata, Status, Containers, Conditions, Events.
#   Los Events al final son ORO para diagnosticar ImagePullBackOff,
#   FailedScheduling, Unhealthy (readiness/liveness), etc.

# 5. LOGS: stdout/stderr del contenedor.
kubectl logs web | tail -5
#   nginx:alpine escribe su banner y luego access logs cuando reciba requests.

kubectl logs -f --tail=20 web &
LOGS_PID=$!

# Dispararle tráfico desde el host via port-forward.
# 6. PORT-FORWARD: túnel local vía apiserver.
kubectl port-forward pod/web 8080:80 >/tmp/k8s-02-ex02/pf.log 2>&1 &
PF_PID=$!
sleep 2

curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/no-existe
sleep 1

# Terminar los procesos de background.
kill "$PF_PID" "$LOGS_PID" 2>/dev/null

# 7. EXEC: proceso adicional dentro del Pod.
kubectl exec web -- nginx -v
#   stderr: nginx version: nginx/1.XX.X
kubectl exec web -- ps -ef
#   PID 1 es nginx master. Tu "ps -ef" aparece como PID efímero.

# 8. EXEC interactivo.
# (Comentado para scripts; pruébalo a mano)
# kubectl exec -it web -- sh

# 9. Explorar la IP interna.
IP="$(kubectl get pod web -o jsonpath='{.status.podIP}')"
echo "Pod IP interna: $IP (no accesible desde el host sin port-forward)"

# 10. Un extracto en JSONPath.
kubectl get pod web -o jsonpath='{.spec.containers[*].image}{"\n"}'
kubectl get pod web -o custom-columns=NAME:.metadata.name,IMG:.spec.containers[*].image,NODE:.spec.nodeName

# 11. Eliminar.
kubectl delete pod web
#   Envía DELETE; el apiserver pone deletionTimestamp; el kubelet termina
#   el contenedor con SIGTERM (grace period 30 s por default), y el objeto
#   se borra del store.
```

## Resultado esperado

- `kubectl get pod web` muestra `1/1 Running`.
- `kubectl describe pod web` tiene al menos un Event `Pulled`/`Started`.
- `curl http://localhost:8080` devuelve HTTP 200 mientras `port-forward` corre.
- `kubectl exec web -- nginx -v` imprime la versión.
- Tras `kubectl delete pod web`, `kubectl get pods` ya no lo lista.

## Limpieza

```bash
kubectl delete pod web --ignore-not-found
kill "$PF_PID" "$LOGS_PID" 2>/dev/null
rm -rf /tmp/k8s-02-ex02
```

## Preguntas de reflexión

1. `kubectl logs web` sigue funcionando después de `kubectl delete pod web`? Experimenta y explica.
2. Si matas el apiserver (en kind: `docker exec kind-control-plane crictl stop <id-apiserver>`), ¿qué pasa con tu `port-forward` activo?
3. ¿Por qué `kubectl exec -it` requiere `-i` **y** `-t`? ¿Qué pasa si solo pones `-t`?
4. `kubectl describe` imprime eventos; ¿de dónde los saca? Pista: `kubectl get events -n default --sort-by=.lastTimestamp`.
