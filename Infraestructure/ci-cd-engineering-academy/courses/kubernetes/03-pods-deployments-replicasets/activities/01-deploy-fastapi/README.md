# k8s-03-01 — Primer Deployment (stand-in de FastAPI)

## 1. Identificación

- **ID:** `k8s-03-01-deploy-fastapi`
- **Tecnología:** kubernetes
- **Módulo:** `03-pods-deployments-replicasets`
- **Dificultad:** beginner
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a desplegar tu primer **servicio** en Kubernetes como un **Deployment**: 3 réplicas, estrategia explícita, labels pensadas, y rolling update verificado. En vez de meter un FastAPI real (todavía no vimos imágenes ni Services), usamos `nginxdemos/hello` como stand-in: imagen pública, respuesta HTTP distinguible por tag, perfecta para observar un rollout. El patrón que practicas aquí es el que vas a reutilizar en TODO el resto del curso.

El validador comprueba el estado final del cluster: el Deployment existe en el namespace correcto, con el nombre, image, replicas, labels, selector y strategy correctos, y el rollout está completo.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un Deployment desde cero con `selector`, `template`, `strategy` y `revisionHistoryLimit` explícitos.
- Aplicar el manifest con `kubectl apply -f`.
- Esperar al rollout con `kubectl rollout status`.
- Inspeccionar la cadena Deployment → ReplicaSet → Pods con `kubectl get deploy,rs,pods -l app=...`.
- Explicar por qué `strategy.rollingUpdate.maxUnavailable: 0` es el default más seguro.

## 4. Prerrequisitos

- `kubectl` ≥ 1.28, `kind` ≥ 0.20 **o** cualquier cluster local (docker-desktop, k3d, minikube).
  - Si no tienes cluster: `kind create cluster --name k8s-03`.
- Docker daemon arriba (para kind). Sin costo (imágenes públicas).
- Namespace `k8s-03-01` (lo crearás en el paso 1).

Si `kubectl` o `kind` no están instalados, el validador imprime `SKIP` y sale 0.

## 5. Instrucciones

Trabaja en `/tmp/k8s-03-01/`:

```bash
mkdir -p /tmp/k8s-03-01 && cd /tmp/k8s-03-01
```

### Paso 1 — namespace aislado

```bash
kubectl create namespace k8s-03-01 --dry-run=client -o yaml | kubectl apply -f -
```

### Paso 2 — escribe `deployment.yaml`

Crea `/tmp/k8s-03-01/deployment.yaml` con **exactamente** estos requisitos (el validador los verifica):

- `metadata.namespace: k8s-03-01`
- `metadata.name: fastapi-stub`
- `metadata.labels`: debe incluir `app: fastapi-stub` **y** `component: web`.
- `spec.replicas: 3`
- `spec.revisionHistoryLimit: 5`
- `spec.strategy.type: RollingUpdate`
- `spec.strategy.rollingUpdate.maxSurge: 1`
- `spec.strategy.rollingUpdate.maxUnavailable: 0`
- `spec.selector.matchLabels`: debe incluir `app: fastapi-stub` **y** `component: web`.
- `spec.template.metadata.labels`: `app: fastapi-stub` y `component: web`.
- `spec.template.spec.containers[0].name: web`
- `spec.template.spec.containers[0].image: nginxdemos/hello:plain-text`
- `spec.template.spec.containers[0].ports[0].containerPort: 80`

**Pista**: puedes partir del ejemplo mínimo de la lección (sección 5) y adaptarlo. **No copies un YAML de internet**: escríbelo tú para fijar la estructura.

### Paso 3 — aplicar y esperar

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/fastapi-stub -n k8s-03-01 --timeout=120s
```

### Paso 4 — inspeccionar la cadena

```bash
kubectl get deploy,rs,pods -n k8s-03-01 -l app=fastapi-stub
kubectl describe deployment fastapi-stub -n k8s-03-01 | grep -E 'Strategy|RollingUpdate|Replicas'
```

Deberías ver:

- 1 Deployment `fastapi-stub` con `3/3 ready`.
- 1 ReplicaSet `fastapi-stub-<hash>` con `3` desired/current/ready.
- 3 Pods `fastapi-stub-<hash>-<suffix>`, todos `Running`.

### Paso 5 — provocar un rolling update para fijar el modelo

```bash
kubectl set image deployment/fastapi-stub web=nginx:1.27-alpine -n k8s-03-01
kubectl annotate deployment/fastapi-stub -n k8s-03-01 \
  kubernetes.io/change-cause="bump to nginx 1.27-alpine" --overwrite
kubectl rollout status deployment/fastapi-stub -n k8s-03-01 --timeout=120s
kubectl rollout history deployment/fastapi-stub -n k8s-03-01
```

Deberías ver 2 revisiones en el historial, y 2 ReplicaSets (uno con 3/3, otro con 0/0).

### Paso 6 — vuelve el tag original (lo que el validador espera)

```bash
kubectl set image deployment/fastapi-stub web=nginxdemos/hello:plain-text -n k8s-03-01
kubectl rollout status deployment/fastapi-stub -n k8s-03-01 --timeout=120s
```

### Paso 7 — validar

```bash
bash courses/kubernetes/03-pods-deployments-replicasets/activities/01-deploy-fastapi/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl get deploy -n k8s-03-01 fastapi-stub -o wide` muestra `READY 3/3`, `IMAGE nginxdemos/hello:plain-text`.
- `kubectl get rs -n k8s-03-01 -l app=fastapi-stub` muestra al menos **dos** ReplicaSets (uno con 3 ready, otros con 0 — pruebas del rolling update).
- `kubectl rollout history deployment/fastapi-stub -n k8s-03-01` muestra ≥ 2 revisiones.
- `tests/validate.sh` imprime `RESULT: PASS`.

## 7. Criterios de aceptación

- Deployment escrito **por ti**, no una copia literal del ejemplo.
- `selector.matchLabels` incluye `app` **y** `component` (no solo `app`).
- `maxUnavailable: 0` (justifica en tus notas por qué es más seguro).
- La anotación `kubernetes.io/change-cause` quedó en al menos una revisión.
- Al terminar, dejas el namespace limpio con el procedimiento de la sección 11.

## 8. Validación

```bash
bash courses/kubernetes/03-pods-deployments-replicasets/activities/01-deploy-fastapi/tests/validate.sh
```

El script imprime `SKIP` (exit 0) si `kubectl` no está disponible o el cluster no responde.

## 9. Preguntas de reflexión

1. ¿Qué habría pasado si tu `selector.matchLabels` fuera `{app: fastapi-stub}` pero el `template.metadata.labels` también tuviera `{env: dev}`? ¿Y al revés?
2. En el paso 5, cuántos Pods máximo coexistieron durante el rollout? ¿Qué parámetro lo controla?
3. ¿Por qué no modificamos el Pod directamente para "probar algo rápido"?
4. Si cambias `replicas: 3` a `replicas: 5` con `kubectl scale`, ¿se crea un nuevo ReplicaSet o se escala el existente? ¿Por qué?

## 10. Extensiones

- Añade un **sidecar nativo** `log-tail` (`initContainer` con `restartPolicy: Always`) que escriba `tailing...` cada 5 s en stdout. Verifica con `kubectl logs <pod> -c log-tail` que vive junto al main.
- Cambia la estrategia a `Recreate` y repite el `set image`. Observa con `kubectl get pods -w` el hueco de 0 Pods.
- Baja `revisionHistoryLimit` a `2`, haz 4 rollouts seguidos, mira `kubectl get rs` y `kubectl rollout history`.

## 11. Limpieza

```bash
kubectl delete namespace k8s-03-01 --ignore-not-found
rm -rf /tmp/k8s-03-01
# Si creaste un cluster solo para esto:
# kind delete cluster --name k8s-03
```
