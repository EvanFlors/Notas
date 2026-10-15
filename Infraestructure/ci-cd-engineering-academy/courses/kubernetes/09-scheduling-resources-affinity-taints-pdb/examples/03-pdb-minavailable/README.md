# Ejemplo 03 — PodDisruptionBudget con `minAvailable`

## Concepto que demuestra

Un PDB con `minAvailable: 2` protege un Deployment de 3 réplicas durante **disrupción voluntaria**. Lo verificamos drenando un worker con `kubectl drain`: K8s **expulsa un Pod** (deja 2), luego otros Pods del nodo. Si pidieras drenar un segundo worker simultáneamente, el eviction del tercero sería **bloqueado** por el PDB.

## Contexto

Usamos el mismo cluster `kind` de 3 workers del ejemplo 02 (`kind-3-workers.yaml`). Sin anti-afinidad, las réplicas pueden terminar en 2 o 3 nodos distintos; el escenario demuestra el PDB de forma independiente a la colocación.

## Objetivo

Al terminar sabrás:

- Cómo expresar `minAvailable` y leer su estado (`.status.disruptionsAllowed`).
- Qué pasa en `kubectl drain` cuando el PDB sería violado.
- Cómo distinguir "espera" (comportamiento correcto) de "falla" (uso incorrecto).

## Prerrequisitos

- Cluster `kind` con 3 workers (del ejemplo 02).
- `kubectl` ≥ 1.28.

## Ejecución

```bash
# 0. Reutiliza o crea el cluster multi-worker.
if ! kind get clusters | grep -qx k8s09; then
  kind create cluster --name k8s09 --config ../02-anti-affinity-across-zones/kind-3-workers.yaml
fi

# 1. Namespace y recursos.
kubectl create namespace k8s09-pdb --dry-run=client -o yaml | kubectl apply -f -
kubectl -n k8s09-pdb apply -f manifests.yaml

# 2. Espera 3 réplicas Ready.
kubectl -n k8s09-pdb rollout status deployment/critical --timeout=120s

# 3. Mira el estado del PDB.
kubectl -n k8s09-pdb get pdb critical-pdb
#   Debe mostrar MIN AVAILABLE 2, ALLOWED DISRUPTIONS 1
#   (puedes "perder" 1 Pod antes de violar el budget).

kubectl -n k8s09-pdb get pdb critical-pdb \
  -o jsonpath='{"disruptionsAllowed="}{.status.disruptionsAllowed}{"\n"}'

# 4. Mira dónde están las réplicas.
kubectl -n k8s09-pdb get pod -o wide

# 5. Elige un worker con pod del Deployment y drénalo.
#    kind nombra workers como k8s09-worker, k8s09-worker2, k8s09-worker3.
NODE=$(kubectl -n k8s09-pdb get pod -l app=critical \
  -o jsonpath='{.items[0].spec.nodeName}')
echo "Vamos a drenar: $NODE"

# NOTA: drain es asíncrono. Lo lanzamos y observamos.
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=90s

# 6. Verifica: siguen al menos 2 Pods Ready. La réplica que estaba en $NODE
#    se recreó en otro worker (porque el drain cordoned el nodo).
kubectl -n k8s09-pdb get pod -o wide

# 7. Descordona para volver al estado inicial.
kubectl uncordon "$NODE"

# 8. ESCENARIO DE FALLO DELIBERADO: baja el PDB a minAvailable=3 (= todas)
#    y vuelve a intentar drain. drain quedará bloqueado hasta timeout.
kubectl -n k8s09-pdb patch pdb critical-pdb --type merge -p '{"spec":{"minAvailable":3}}'
kubectl -n k8s09-pdb get pdb critical-pdb
#   ALLOWED DISRUPTIONS debería ser 0.

NODE2=$(kubectl -n k8s09-pdb get pod -l app=critical \
  -o jsonpath='{.items[0].spec.nodeName}')
echo "Intentando drain de $NODE2 con PDB imposible (timeout corto)..."
# Esperamos que falle con un timeout — es la señal de que el PDB está haciendo su trabajo.
kubectl drain "$NODE2" --ignore-daemonsets --delete-emptydir-data --timeout=20s || \
  echo "OK: drain bloqueado por PDB (esperado)."

kubectl uncordon "$NODE2"
# Restaura el PDB a un valor sensato.
kubectl -n k8s09-pdb patch pdb critical-pdb --type merge -p '{"spec":{"minAvailable":2}}'
```

## Resultado esperado

- Primer `drain`: finaliza; sigue habiendo **≥ 2** Pods Ready.
- Segundo `drain` (con PDB imposible `minAvailable: 3`): no termina en 20 s y imprime "OK: drain bloqueado por PDB (esperado)".

## Limpieza

```bash
kubectl delete namespace k8s09-pdb --ignore-not-found
# Si no vas a usarlo más:
# kind delete cluster --name k8s09
```

## Preguntas de reflexión

1. Cambia `minAvailable: 2` por `maxUnavailable: 1`. ¿Qué diferencia operativa hay para un Deployment de 3 réplicas?
2. Si la app crashea sola (sin que nadie drene), ¿el PDB la protege? Explica por qué sí o no.
3. ¿Qué recomendaría combinar con un PDB para que `drain` sea verdaderamente seguro? Pista: `preStop` y `terminationGracePeriodSeconds` (lo cubre `k8s-10`).
4. En un Deployment de **1** réplica con `minAvailable: 1`, ¿qué pasa en el próximo `drain`? ¿Es un bug tuyo o del cluster operator?
