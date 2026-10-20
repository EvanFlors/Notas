# k8s-09-01 — Afinar requests/limits y clasificar la QoS

## 1. Identificación

- **ID:** `k8s-09-01-tune-resources-and-measure`
- **Tecnología:** kubernetes
- **Módulo:** `09-scheduling-resources-affinity-taints-pdb`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a tomar un Deployment "api" sin resources declarados (QoS `BestEffort`) y convertirlo a `Guaranteed` con valores razonables para una carga pequeña. La actividad fuerza las dos lecciones centrales del módulo: (a) los `requests` informan al scheduler, (b) `requests == limits` define `Guaranteed`.

Guided lab: el `starter/deployment.yaml` tiene TODOs explícitos; la `solution/` muestra la respuesta canónica.

## 3. Objetivos

Al terminar deberías poder:

- Escribir `resources.requests` y `resources.limits` con unidades correctas (`m` para CPU, `Mi` para memoria).
- Lograr `status.qosClass: Guaranteed` sin trucos.
- Explicar por qué `BestEffort` es la primera víctima bajo presión del nodo.
- Describir en una línea la diferencia entre OOMKill y CPU throttling.

## 4. Prerrequisitos

- Cluster `kind` (o compatible). Si no tienes, créalo:
  ```bash
  kind create cluster --name k8s09-act1
  ```
- `kubectl` ≥ 1.28.
- Namespace scratch que puedas borrar.
- Sin costo (todo local).

## 5. Instrucciones

Trabaja en `/tmp/k8s-09-01/`. Si existe, bórralo primero.

```bash
rm -rf /tmp/k8s-09-01
mkdir -p /tmp/k8s-09-01
cp -r starter/* /tmp/k8s-09-01/
cd /tmp/k8s-09-01
```

### Paso 1 — crea el namespace

```bash
kubectl create namespace k8s-09-01 --dry-run=client -o yaml | kubectl apply -f -
```

### Paso 2 — edita `deployment.yaml`

Añade `resources` al contenedor `app`. Reglas que verifica el validador:

- `requests.cpu == limits.cpu`.
- `requests.memory == limits.memory`.
- `requests.cpu`:    entre `50m` y `500m`.
- `requests.memory`: entre `32Mi` y `256Mi`.

El Pod resultante debe tener `status.qosClass: Guaranteed`.

### Paso 3 — aplica y verifica

```bash
kubectl -n k8s-09-01 apply -f deployment.yaml
kubectl -n k8s-09-01 rollout status deployment/api --timeout=60s

# Mira la QoS que te asignó K8s:
kubectl -n k8s-09-01 get pod -l app=api \
  -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

### Paso 4 — ejecuta el validador

```bash
bash tests/validate.sh
```

Debe terminar con `PASS` y exit 0.

### Paso 5 — reflexión escrita (opcional pero recomendado)

En `/tmp/k8s-09-01/NOTES.md` escribe, en 3-5 líneas, cómo diferencias un OOMKill de un throttling por lo que ves en `kubectl describe pod` y en métricas.

## 6. Resultado esperado

- Deployment `api` en namespace `k8s-09-01`, 2 réplicas Ready.
- Los Pods tienen `status.qosClass: Guaranteed`.
- Validador reporta `PASS`.

## 7. Criterios de aceptación

- `requests` y `limits` iguales en CPU y memoria.
- Valores dentro de los rangos indicados.
- 2 réplicas Running.
- `bash tests/validate.sh` exit 0.

## 8. Validación

```bash
bash tests/validate.sh
# o con namespace alternativo:
NS=mi-ns bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si subes `limits.memory` por encima de `requests.memory`, ¿qué pasa con la clase QoS? ¿Y con la probabilidad de que el kernel elija este Pod para OOM-kill?
2. ¿Por qué en producción algunos equipos **no** limitan `cpu`?
3. Dado un contenedor con `requests.cpu: 2` en un cluster `kind` single-node de 2 cores, ¿quedará `Pending`? ¿Qué otros Pods del `kube-system` compiten por esos cores?
4. Dibuja (en papel) qué `oom_score_adj` esperarías para `Guaranteed`, `Burstable` y `BestEffort`.

## 10. Extensiones

- Añade un segundo contenedor sidecar (p. ej. `nginx:alpine`) **sin** resources. Observa cómo el Pod entero deja de ser `Guaranteed`. Arregla el sidecar.
- Añade `ephemeral-storage` a los `requests/limits`. Verifica con `kubectl describe node` que suma al reservado.
- Crea un `LimitRange` en el namespace que ponga defaults de `requests/limits`. Elimina el bloque `resources` del Deployment y mira cómo el namespace lo rellena.

## 11. Limpieza

```bash
kubectl delete namespace k8s-09-01 --ignore-not-found
rm -rf /tmp/k8s-09-01
# Opcional:
# kind delete cluster --name k8s09-act1
```
