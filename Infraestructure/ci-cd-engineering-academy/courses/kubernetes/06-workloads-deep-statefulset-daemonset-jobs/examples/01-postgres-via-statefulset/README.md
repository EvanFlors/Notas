# Ejemplo 01 — Postgres via `StatefulSet` con PVC

## Concepto que demuestra

- `StatefulSet` con `volumeClaimTemplates` → PVC estable por réplica.
- Headless `Service` (`clusterIP: None`) → DNS por Pod (`pg-0.pg.default.svc.cluster.local`).
- Identidad estable (`pg-0` siempre es `pg-0`).
- **Persistencia real**: borras el Pod, el controller lo recrea, el PVC se re-monta, el dato sigue ahí.

## Contexto

Es el "hola mundo" útil de un `StatefulSet`. No es un Postgres de producción (una sola réplica, sin backup, sin tuning, password *dummy* en el manifest). Sirve para **ver con tus ojos** que el PVC sobrevive al Pod.

## Objetivo

Al terminar sabrás:

- Qué le añade un `StatefulSet` sobre un `Deployment`.
- Por qué el headless `Service` es obligatorio.
- Qué pasa cuando borras un Pod de un STS.
- Qué pasa cuando borras el STS entero (spoiler: los PVC siguen vivos).

## Prerrequisitos

- Cluster local `kind` corriendo. Si no:
  ```bash
  kind create cluster --name k8s-06
  ```
- `kubectl` con contexto al cluster.
- La `StorageClass` default del cluster (en `kind`: `standard` con el provisioner `rancher.io/local-path`).

## Ejecución

```bash
# 0. Verifica que no hay restos de corridas anteriores
kubectl get statefulset pg 2>/dev/null && kubectl delete statefulset pg
kubectl get pvc -l app=pg 2>/dev/null && kubectl delete pvc -l app=pg

# 1. Aplica el manifest
kubectl apply -f manifests/postgres.yaml

# 2. Observa cómo se crea el PVC primero y luego el Pod `pg-0`
kubectl get pvc -w &
WPID=$!
sleep 2
kubectl get pods -l app=pg -w &
WPID2=$!
# Espera a Ready
kubectl rollout status statefulset/pg --timeout=180s
kill $WPID $WPID2 2>/dev/null || true

# 3. DNS por Pod — comprueba que `pg-0.pg` resuelve dentro del cluster
kubectl run -i --rm --restart=Never dnsprobe --image=busybox:1.36 -- \
  nslookup pg-0.pg.default.svc.cluster.local

# 4. Dato de prueba: crea una tabla y una fila
kubectl exec -it pg-0 -- psql -U postgres -d demo -c "CREATE TABLE IF NOT EXISTS t (id serial primary key, msg text);"
kubectl exec -it pg-0 -- psql -U postgres -d demo -c "INSERT INTO t(msg) VALUES ('hola k8s-06');"
kubectl exec -it pg-0 -- psql -U postgres -d demo -c "SELECT * FROM t;"

# 5. Mata el Pod y confirma que el dato sobrevive
kubectl delete pod pg-0
kubectl rollout status statefulset/pg --timeout=120s
kubectl exec -it pg-0 -- psql -U postgres -d demo -c "SELECT * FROM t;"
#   -> la fila 'hola k8s-06' sigue ahí.

# 6. Mira los recursos reales
kubectl get statefulset pg
kubectl get pods -l app=pg
kubectl get pvc -l app=pg
kubectl get pv
```

## Resultado esperado

- `kubectl rollout status statefulset/pg` devuelve `partitioned roll out complete: 1 new pods have been updated...` o equivalente, dentro de 2-3 min.
- `nslookup pg-0.pg.default.svc.cluster.local` devuelve una IP.
- La `SELECT` del paso 6 devuelve la fila `(1, 'hola k8s-06')` **también después de borrar el Pod**.
- `kubectl get pvc` muestra `data-pg-0` con status `Bound`.

## Qué pasa si borras el STS

```bash
kubectl delete statefulset pg
kubectl get pvc            # data-pg-0 SIGUE AHÍ — intencional
kubectl apply -f manifests/postgres.yaml
kubectl rollout status statefulset/pg --timeout=120s
kubectl exec -it pg-0 -- psql -U postgres -d demo -c "SELECT * FROM t;"
#   -> dato recuperado.
```

Para limpiar de verdad:

```bash
kubectl delete statefulset pg --ignore-not-found
kubectl delete pvc -l app=pg --ignore-not-found
kubectl delete svc pg --ignore-not-found
```

## Preguntas de reflexión

1. ¿Qué devuelve `nslookup pg.default.svc.cluster.local` (sin el `pg-0.` delante)? ¿Por qué?
2. Si cambias `clusterIP: None` por un ClusterIP normal, ¿qué pasa con `nslookup pg-0.pg...`?
3. Escala el STS a 2 réplicas con `kubectl scale sts pg --replicas=2`. ¿Qué nuevo PVC aparece? ¿`pg-1` tiene los mismos datos que `pg-0`?
4. ¿Qué cambiarías para operar esto "en serio" (producción)? Lista mínimo 5 cosas.

## Limpieza

```bash
kubectl delete statefulset pg --ignore-not-found
kubectl delete pvc -l app=pg --ignore-not-found
kubectl delete svc pg --ignore-not-found
```
