# Ejemplo 02 — Pod anti-affinity por zona

## Concepto que demuestra

`podAntiAffinity` con `topologyKey: topology.kubernetes.io/zone` fuerza que **no haya dos réplicas** del mismo Deployment en la misma zona. Si no hay zonas suficientes, los Pods extra quedan `Pending`: te enseña por qué `required` es peligroso con poca topología.

## Contexto

Un cluster real asigna automáticamente labels `topology.kubernetes.io/zone` a cada nodo (EKS/GKE/AKS lo hacen). En **kind**, los asignamos a mano con el `kind-3-workers.yaml` incluido: tres workers etiquetados como `zone-a`, `zone-b`, `zone-c`.

## Objetivo

Al terminar sabrás:

- Cómo escribir anti-affinity "duro" (`required...`) por zona.
- Cómo verificar que las réplicas aterrizaron en zonas distintas.
- Qué pasa (y cómo diagnosticarlo) cuando pides 4 réplicas en 3 zonas con `required`.

## Prerrequisitos

- `kind` ≥ 0.23 instalado. `docker` o compatible.
- `kubectl` ≥ 1.28.
- Puertos 6443, 80, 443 del host no colisionando con otros clusters.
- Sin costo (todo local).

## Ejecución

```bash
# 0. Crea cluster multi-worker con labels de zona.
kind create cluster --name k8s09 --config kind-3-workers.yaml

# 1. Confirma los labels de zona.
kubectl get nodes -L topology.kubernetes.io/zone

# NAME                 STATUS   ROLES           ZONE
# k8s09-control-plane  Ready    control-plane
# k8s09-worker         Ready    <none>          zone-a
# k8s09-worker2        Ready    <none>          zone-b
# k8s09-worker3        Ready    <none>          zone-c

# 2. Namespace y Deployment con anti-afinidad.
kubectl create namespace k8s09-anti --dry-run=client -o yaml | kubectl apply -f -
kubectl -n k8s09-anti apply -f deployment.yaml

# 3. Espera a Running (3 réplicas, una por zona).
kubectl -n k8s09-anti rollout status deployment/payments --timeout=120s

# 4. Observa en qué nodo (y por lo tanto en qué zona) aterrizó cada Pod.
kubectl -n k8s09-anti get pods -o wide \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase

# Las 3 réplicas deben estar en 3 nodos distintos (una por zona).

# 5. ESCENARIO: escala a 4 réplicas. Solo hay 3 zonas → la 4ª queda Pending.
kubectl -n k8s09-anti scale deployment/payments --replicas=4
sleep 5
kubectl -n k8s09-anti get pods
#   Verás 3 Running y 1 Pending.

# 6. Lee el evento del scheduler: te dice exactamente por qué.
PENDING=$(kubectl -n k8s09-anti get pod -l app=payments \
  --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
kubectl -n k8s09-anti describe pod "$PENDING" | sed -n '/Events:/,$p'
#   Buscarás algo como: "didn't match pod anti-affinity rules".

# 7. Vuelve a 3 réplicas: el Pending desaparece.
kubectl -n k8s09-anti scale deployment/payments --replicas=3
kubectl -n k8s09-anti rollout status deployment/payments --timeout=60s
```

## Resultado esperado

- Las 3 réplicas iniciales corren en **3 zonas distintas**.
- Al escalar a 4, exactamente **1** Pod queda `Pending`.
- `describe` del Pod Pending menciona `didn't match pod anti-affinity rules`.

## Limpieza

```bash
kubectl delete namespace k8s09-anti --ignore-not-found
# Si no vas a usar el cluster para los otros ejemplos:
kind delete cluster --name k8s09
```

## Preguntas de reflexión

1. Cambia `required...` por `preferred...`. ¿Qué pasa al escalar a 4? ¿Por qué ahora no hay `Pending`?
2. Reemplaza el bloque `podAntiAffinity` por `topologySpreadConstraints` con `maxSkew: 1`, `topologyKey: zone`, `whenUnsatisfiable: ScheduleAnyway`. ¿Qué cambia con 5 réplicas?
3. ¿Qué pasaría en un cluster EKS real con `topologyKey: topology.kubernetes.io/region` y réplicas en una sola región?
4. ¿Por qué `required` es caro de calcular para el scheduler en clusters grandes?
