# Ejemplo 03 — `maxSurge` / `maxUnavailable` + PDB

Demuestra el tuning conservador para una app crítica: `maxUnavailable: 0`, `maxSurge: 1`, protegido por un PodDisruptionBudget.

## Qué muestra

- Durante el rollout, el Deployment nunca baja de `replicas` ready (es decir, sin pérdida de capacidad).
- Un `kubectl drain` concurrente **se bloquea** si viola el PDB.
- El rollout avanza un Pod a la vez (más lento, más seguro).

## Requisitos

- Cluster local.
- `kubectl`.

## Cómo correrlo

```bash
mkdir -p /tmp/k8s-10-ex03 && cd /tmp/k8s-10-ex03

kubectl apply -f manifest.yaml
kubectl rollout status deployment/rollout-tune --timeout=120s

# Observa el estado inicial
kubectl get pods -l app=rollout-tune

# Dispara una actualización
kubectl set env deployment/rollout-tune VERSION=v2

# En paralelo, observa el rollout (verás +1 Pod en Pending antes de retirar uno viejo)
kubectl get pods -l app=rollout-tune -w &
WATCH_PID=$!
kubectl rollout status deployment/rollout-tune --timeout=180s
kill $WATCH_PID 2>/dev/null || true

# PDB en acción: cuenta de Pods permitidos a desaparecer
kubectl get pdb rollout-tune
```

## Qué observar

- `kubectl get pods` durante el rollout: verás **4** Pods a veces (3 ready + 1 nuevo arrancando), nunca menos de 3 ready.
- `kubectl get pdb rollout-tune` muestra `ALLOWED DISRUPTIONS: 1` cuando todo está ready. Durante el rollout baja a 0 → cualquier `drain` externo esperará.

## Limpieza

```bash
kubectl delete -f manifest.yaml
rm -rf /tmp/k8s-10-ex03
```
