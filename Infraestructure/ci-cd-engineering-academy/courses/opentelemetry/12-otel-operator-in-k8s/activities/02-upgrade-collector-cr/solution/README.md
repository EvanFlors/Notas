# otel-12-02 — Solución de referencia

## Flujo

```bash
bash starter/setup.sh
kubectl apply -f solution/upgradable-v1.yaml
kubectl -n observability rollout status deploy/upgradable-collector --timeout=120s

# Antes/después de la operación
kubectl -n observability get rs -l app.kubernetes.io/managed-by=opentelemetry-operator -o wide
kubectl -n observability get cm -l app.kubernetes.io/managed-by=opentelemetry-operator -o name
kubectl -n observability get otelcol upgradable -o jsonpath='{.spec.image}{"\n"}'
kubectl -n observability get otelcol upgradable -o jsonpath='{.spec.config.processors}{"\n"}'
```

## Qué cambió

- `spec.image`: `0.110.0 → 0.111.0` (upgrade de minor).
- `spec.config.processors`: añadido `attributes/env` que inserta `deployment.environment=lab`.
- `spec.config.service.pipelines.traces.processors`: incluye el nuevo processor antes de `batch`.

Ambos cambios disparan rollouts separados: el de `spec.image` cambia el pod template; el de `spec.config` cambia el nombre del ConfigMap renderizado (hash distinto) → nuevo pod template → rolling update.

## Respuestas a las preguntas de reflexión

1. **ConfigMap con hash en el nombre**: para que cualquier cambio de config genere un objeto nuevo que el controlador referencia en el pod template. Así el rolling update es automático; si editases el CM in-place, los pods no se enterarían (el kubelet no reinicia por un CM cambiado salvo que uses `reloader`).
2. **Colisiones entre namespaces**: no colisionan — los Deployments y Services viven en su namespace. Lo que sí comparten es el **ClusterRole**/ClusterRoleBinding generados para `k8sattributes` (son cluster-scoped). El Operator usa nombres con sufijo para evitar choques.
3. **Pinear vs default**: en entornos con **cambio frecuente del Operator** (quincenal, Argo trackeando `latest`) sin pin → cualquier upgrade del Operator rolla *todos* los Collectors. Pinear da upgrades predecibles. Decisión depende de: criticidad del pipeline de telemetría, SLA, y si el equipo prefiere "una herramienta menos que recordar".
4. **GitOps + Operator**: Argo re-aplica el `spec` del CR; el Operator reconcilia los objetos derivados. Si el Operator añade `annotations` o `labels` al Deployment generado, Argo *no* ve esos campos (su source of truth es el CR). No hay drift porque Argo gestiona el CR y los objetos derivados son hijos del CR, no de Argo. Riesgo: si alguien `kubectl patch`ea el CR fuera de Git, Argo lo revierte; el Operator rolla.
5. **Rollback de config**: `kubectl apply` del CR anterior (o `git revert` si está en GitOps). Como el ConfigMap vive por hash, el Operator "reactiva" el CM anterior (o lo recrea) y el Deployment vuelve al template previo.
