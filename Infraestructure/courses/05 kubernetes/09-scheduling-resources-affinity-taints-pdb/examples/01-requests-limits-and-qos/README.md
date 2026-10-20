# Ejemplo 01 — Requests, limits y las tres QoS classes

## Concepto que demuestra

Cómo Kubernetes **deriva** la QoS a partir de `resources`. Tres Pods idénticos salvo por sus `requests/limits` producen las tres clases: `Guaranteed`, `Burstable`, `BestEffort`.

## Contexto

Usamos la imagen `registry.k8s.io/pause:3.9` porque no hace nada (no se mide, no se estresa, no se cae). Lo que miramos es puramente **declarativo**: cómo K8s interpreta tu spec.

## Objetivo

Al terminar sabrás:

- Qué regla exacta clasifica a cada Pod.
- Dónde se ve la clase en el objeto (`.status.qosClass`).
- Qué significa `BestEffort` en orden de eviction.

## Prerrequisitos

- Cluster `kind` o cualquier K8s accesible (`kubectl config current-context`).
- `kubectl` ≥ 1.28.

Si no tienes cluster, crea uno rápido:

```bash
kind create cluster --name k8s09-qos
```

## Ejecución

```bash
# 0. Namespace scratch, aislado.
kubectl create namespace k8s09-qos --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=k8s09-qos

# 1. Aplica los tres Pods.
kubectl apply -f pods.yaml

# 2. Espera a que estén Running.
kubectl wait --for=condition=Ready pod -l demo=qos --timeout=60s

# 3. Lee la QoS clasificada por K8s (no la declaraste tú; la deriva).
kubectl get pod -l demo=qos \
  -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# Salida esperada:
# NAME             QOS
# qos-besteffort   BestEffort
# qos-burstable    Burstable
# qos-guaranteed   Guaranteed

# 4. Confirma con describe (sección "QoS Class:").
kubectl describe pod qos-guaranteed | grep -E "QoS Class"
kubectl describe pod qos-burstable  | grep -E "QoS Class"
kubectl describe pod qos-besteffort | grep -E "QoS Class"

# 5. Verifica que el scheduler reservó los requests correctos en el nodo.
NODE=$(kubectl get pod qos-guaranteed -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | sed -n '/Non-terminated Pods/,/Allocated resources/p'
```

## Resultado esperado

- Los tres Pods están `Running`.
- `qos-guaranteed` → `Guaranteed`.
- `qos-burstable`  → `Burstable`.
- `qos-besteffort` → `BestEffort`.
- `describe node` muestra `qos-guaranteed` reservando 100m/64Mi y `qos-burstable` reservando 50m/32Mi; `qos-besteffort` aparece sin requests.

## Limpieza

```bash
kubectl delete -f pods.yaml --ignore-not-found
kubectl delete namespace k8s09-qos --ignore-not-found
# opcional: kind delete cluster --name k8s09-qos
```

## Preguntas de reflexión

1. Si quitas `limits.memory` del Pod `qos-guaranteed` (y dejas `requests.memory`), ¿qué clase pasa a tener? ¿Por qué?
2. Un Pod con **dos** contenedores: uno con requests==limits para CPU y memory, y otro con solo `requests.cpu`. ¿Qué clase recibe el Pod? (Regla: para ser Guaranteed, **todos** los contenedores deben cumplir.)
3. ¿Por qué `BestEffort` es útil (y no solo "flojera de declarar")? Pista: batch jobs cancelables.
4. ¿Qué pasa si en un Pod declaras `requests.cpu: 2` en un cluster `kind` single-node con 2 cores reservados por el control plane?
