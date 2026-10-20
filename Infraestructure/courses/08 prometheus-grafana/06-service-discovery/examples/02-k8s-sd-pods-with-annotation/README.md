# 02 — Kubernetes SD con filtro por annotation

Levantamos un cluster `kind`, aplicamos un Prometheus con `role: pod` y dos aplicaciones *dummy*: una anotada con `prometheus.io/scrape=true` y otra sin anotar. Solo la anotada debe aparecer en `/targets`.

## Requisitos

- `kind` ≥ 0.23
- `kubectl` ≥ 1.28
- `docker` corriendo

Si falta alguno:

```bash
command -v kind >/dev/null || { echo "SKIP: kind no instalado"; exit 0; }
command -v kubectl >/dev/null || { echo "SKIP: kubectl no instalado"; exit 0; }
```

## Levantar

```bash
cd "$(dirname "$0")"
kind create cluster --name obs06 --image kindest/node:v1.30.0
kubectl apply -f manifests/
# Esperar readiness
kubectl -n monitoring wait --for=condition=Ready pod -l app=prometheus --timeout=120s
kubectl -n demo wait --for=condition=Ready pod -l app=app-annotated --timeout=120s
kubectl -n demo wait --for=condition=Ready pod -l app=app-unannotated --timeout=120s
```

## Verificar

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

# Solo el pod ANOTADO debe aparecer activo en /targets
curl -s localhost:9090/api/v1/targets \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("\n".join(t["labels"].get("pod","") for t in d["data"]["activeTargets"] if t["labels"].get("job")=="k8s-pods"))'
# → app-annotated-...  (y SOLO ese)

kill $PF_PID
```

## Limpieza

```bash
kind delete cluster --name obs06
```
