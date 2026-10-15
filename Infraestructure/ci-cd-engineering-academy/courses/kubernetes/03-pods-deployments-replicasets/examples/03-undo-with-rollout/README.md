# Ejemplo 03 — Romper un deploy y revertir con `kubectl rollout undo`

## Concepto que demuestra

Rollback automático sin reconstruir YAML: `kubectl rollout undo` usa los **ReplicaSets viejos** (conservados por `revisionHistoryLimit`) para restaurar un template anterior en segundos. También muestra `--to-revision=N` para saltar a una revisión concreta en vez de la inmediatamente anterior.

## Contexto

En producción un rollout "malo" se detecta por alertas (5xx, latency, error de arranque). Lo primero que haces no es diagnosticar — es **revertir** y luego investigar con calma. Este ejemplo simula la falla: hacemos un `set image` a una tag inexistente, vemos cómo el rollout se atasca, y revertimos.

## Objetivo

- Interpretar `kubectl rollout status` cuando se queda esperando.
- Diagnosticar la causa con `kubectl describe` y `kubectl get events`.
- Revertir a la revisión anterior con `kubectl rollout undo`.
- Saltar a una revisión concreta con `--to-revision`.

## Prerrequisitos

- Cluster local kind o k3d.
- Haber hecho el Ejemplo 02 ayuda (misma mecánica).

## Ejecución

```bash
# 0. Entorno limpio.
kubectl delete deployment hello --ignore-not-found

# 1. Baseline en v1.
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

# 2. Rollout "bueno" a v2 (anota la causa de cambio).
kubectl set image deployment/hello web=nginx:1.26-alpine
kubectl annotate deployment/hello kubernetes.io/change-cause="bump to nginx 1.26-alpine" --overwrite
kubectl rollout status deployment/hello --timeout=120s

# 3. Rollout "malo": tag inexistente.
kubectl set image deployment/hello web=nginx:does-not-exist
kubectl annotate deployment/hello kubernetes.io/change-cause="broken: typo in tag" --overwrite

# 4. Mira el rollout atascado (dale ~30 s).
kubectl rollout status deployment/hello --timeout=30s || true
#   Verás "Waiting for deployment ..." y nunca termina.

# 5. Diagnóstico: ¿por qué?
kubectl get pods -l app=hello
#   Hay 3 "viejos" Ready y 1 "nuevo" con ImagePullBackOff.
#   maxUnavailable: 0 impide bajar más viejos antes de que el nuevo esté Ready.

NEW=$(kubectl get pod -l app=hello --field-selector=status.phase!=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$NEW" ] && kubectl describe pod "$NEW" | grep -E 'Image|Pulling|Failed' | head -10

# 6. REVERTIR a la revisión anterior.
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello --timeout=120s
#   Vuelve a estar 3/3 Ready en nginx:1.26-alpine.

kubectl get deployment hello -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

# 7. Historia tras el undo.
kubectl rollout history deployment/hello
#   El undo crea una NUEVA revisión que replica el template de la revisión anterior.
#   Las revisiones intermedias "rotas" quedan registradas para auditar.

# 8. Saltar a la revisión 1 (nginx:1.25-alpine).
kubectl rollout undo deployment/hello --to-revision=1
kubectl rollout status deployment/hello --timeout=120s
kubectl get deployment hello -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
#   Imagen volvió a nginx:1.25-alpine.
```

## Resultado esperado

- Paso 4: `kubectl rollout status` se cuelga; el Pod nuevo queda `ImagePullBackOff`; los viejos siguen Ready. **Sin downtime** (gracias a `maxUnavailable: 0`).
- Paso 6: tras `rollout undo`, en < 30 s el Deployment está 3/3 Ready con `nginx:1.26-alpine`.
- Paso 8: tras `undo --to-revision=1`, la imagen es `nginx:1.25-alpine`.

## Limpieza

```bash
kubectl delete deployment hello --ignore-not-found
```

## Preguntas de reflexión

1. ¿Por qué `maxUnavailable: 0` **salvó** este rollout? ¿Qué hubieras visto con `maxUnavailable: 1`?
2. `kubectl rollout undo` no reconstruye el YAML desde ningún lado — ¿de dónde saca el template viejo?
3. Si `revisionHistoryLimit: 2`, ¿qué habrías visto en el paso 7? ¿Podrías haber vuelto a la revisión 1?
4. ¿Por qué el undo crea una **nueva** revisión en vez de "borrar" la rota?
