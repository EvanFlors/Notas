# Ejemplo 03 — `AnalysisTemplate` con Prometheus

Un `AnalysisTemplate` reutilizable que mide la tasa de 5xx para un servicio dado y gatea la promoción. Enchufado a un `Rollout` canary vía step `analysis`.

## Qué muestra

- Estructura de `AnalysisTemplate` con `args` y `metrics[].provider.prometheus`.
- `successCondition` / `failureCondition` / `failureLimit`.
- Cómo referenciarlo desde un step `analysis` del `Rollout`.

## Requisitos

- Argo Rollouts instalado.
- **Prometheus accesible** desde el cluster (ej. kube-prometheus-stack). La query de ejemplo asume `http_requests_total` con label `code`. Si tu Prometheus no tiene esa métrica, ajusta la query — el *patrón* es lo relevante.

Si no tienes Prometheus a mano: el analysis entrará en `Error` (no `Failed`) por no poder resolver el endpoint, lo que *no* gatilla rollback — pero sirve igual para inspeccionar el `AnalysisRun` creado.

## Cómo correrlo

```bash
mkdir -p /tmp/argo-10-ex03 && cd /tmp/argo-10-ex03
# cp <repo>/.../examples/03-analysis-template-prom/*.yaml .

# Ajusta la dirección de Prometheus en analysistemplate.yaml si hace falta.
kubectl apply -f analysistemplate.yaml
kubectl apply -f rollout.yaml
kubectl apply -f service.yaml

# Dispara el rollout:
kubectl patch rollout canary-analysis-demo --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"nginx:1.27"}]}}}}'

kubectl argo rollouts get rollout canary-analysis-demo --watch &

# Mira los AnalysisRun creados:
kubectl get analysisruns -l rollout=canary-analysis-demo
kubectl describe analysisrun -l rollout=canary-analysis-demo | tail -40
```

## Qué observar

- En el step `analysis` el controller crea un `AnalysisRun` con nombre `canary-analysis-demo-<rev>-<idx>`.
- Fases: `Pending → Running → Successful | Failed | Error | Inconclusive`.
- Si `Failed`, el Rollout entra `Degraded` y abort automático (vuelve al stable).

Forzar un fail intencional (si tienes control de Prometheus de prueba):

```bash
# Cambia successCondition a algo imposible:
kubectl patch analysistemplate error-rate-5xx --type json \
  -p '[{"op":"replace","path":"/spec/metrics/0/successCondition","value":"result[0] < -1"}]'
# dispara otro rollout y observa el abort.
```

## Limpieza

```bash
kill %1 2>/dev/null || true
kubectl delete -f service.yaml -f rollout.yaml -f analysistemplate.yaml --ignore-not-found
rm -rf /tmp/argo-10-ex03
```
