# Ejemplo 02 — Rolling update paso a paso

## Concepto que demuestra

Qué pasa **mecánicamente** cuando un Deployment se actualiza: creación de un nuevo ReplicaSet, escalado del viejo hacia abajo y del nuevo hacia arriba, con las invariantes `maxSurge`/`maxUnavailable` respetadas. Comparación con `strategy: Recreate`.

## Contexto

Un rolling update es la operación cotidiana en producción. Entenderlo en el estado estacionario (3 → 3 Pods, misma imagen) y durante la transición (dos ReplicaSets coexistiendo) es la base para interpretar cualquier incidente futuro: "¿por qué mi rollout no termina?", "¿por qué hay el doble de Pods?", "¿por qué mi app vieja sigue respondiendo?".

## Objetivo

- Observar que una actualización **crea un segundo ReplicaSet**.
- Ver cómo `maxSurge: 1 / maxUnavailable: 0` se traduce en Pods concretos.
- Comparar con `strategy: Recreate`: todos los viejos mueren antes de que nazca el primer nuevo.

## Prerrequisitos

- Cluster local kind o k3d.
- Dos terminales (una para `kubectl get ... -w`).

## Ejecución

### Parte A — RollingUpdate (default) con maxSurge=1 / maxUnavailable=0

```bash
# 0. Entorno limpio.
kubectl delete deployment hello --ignore-not-found

# 1. Deployment inicial en v1.
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
          image: nginx:1.25-alpine
          ports: [{ containerPort: 80 }]
EOF

kubectl rollout status deployment/hello --timeout=120s
kubectl get rs -l app=hello
#   Un solo RS, 3 ready. Anota su nombre.

# 2. (Terminal B) Observa en vivo:
#    kubectl get pods -l app=hello -w
#
# 3. (Terminal A) Dispara un rollout a v2.
kubectl set image deployment/hello web=nginx:1.26-alpine
kubectl rollout status deployment/hello --timeout=180s

# 4. Hay DOS ReplicaSets.
kubectl get rs -l app=hello
#   DESIRED CURRENT READY del viejo = 0,0,0.
#   DESIRED CURRENT READY del nuevo = 3,3,3.

# 5. En Terminal B viste la secuencia:
#    Antes:  3 pods old
#    T+0:    4 pods (3 old + 1 new Pending→ContainerCreating→Running→Ready)
#    T+N:    3 pods (2 old + 1 new) — se mató 1 old al estar ready el nuevo
#    ... y así hasta 0 old / 3 new.

# 6. Mira el historial.
kubectl rollout history deployment/hello
#   REVISION 1 (nginx:1.25-alpine)
#   REVISION 2 (nginx:1.26-alpine)
```

### Parte B — Comparación con `strategy: Recreate`

```bash
# 7. Cambia la estrategia a Recreate.
kubectl patch deployment hello -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'

# 8. (Terminal B sigue mirando) Dispara otro rollout.
kubectl set image deployment/hello web=nginx:1.27-alpine
kubectl rollout status deployment/hello --timeout=180s

# 9. En Terminal B viste la secuencia:
#    Antes:  3 pods v2
#    T+0:    0 pods (los 3 viejos matados a la vez)   ← downtime
#    T+N:    3 pods v3 arrancando desde cero

kubectl rollout history deployment/hello
#   REVISION 3 (nginx:1.27-alpine) añadida.
```

## Resultado esperado

- Parte A: nunca ves menos de 3 Pods Ready a la vez; ves hasta 4 Pods coexistiendo (`maxSurge: 1`).
- Parte B: ves un **hueco** de 0 Pods entre viejo y nuevo. Downtime visible.
- `kubectl get rs -l app=hello` al final de B muestra **tres** ReplicaSets (uno con 3 Ready, dos con 0).

## Limpieza

```bash
kubectl delete deployment hello --ignore-not-found
```

## Preguntas de reflexión

1. ¿Qué habrías visto en Terminal B con `maxSurge: 50%, maxUnavailable: 50%`?
2. Si tu app tarda 15 s en arrancar y no tiene readiness probe, ¿el rolling update "sin downtime" realmente lo es? ¿Qué miente?
3. ¿Por qué sobreviven los ReplicaSets viejos con `replicas: 0` después del rollout?
4. Con `strategy: Recreate`, ¿cómo medirías cuánto duró el downtime real?
