# otel-12-01 — Solución

Los manifests del starter **son** la solución. Esta actividad es un guided-lab: la mecánica es aplicar en orden y verificar.

## Flujo completo (un solo script)

```bash
bash starter/setup.sh
kubectl apply -f /tmp/otel-12-lab/01-gateway.yaml
kubectl -n observability rollout status deploy/gateway-collector --timeout=120s

kubectl apply -f /tmp/otel-12-lab/02-agent.yaml
kubectl -n observability rollout status daemonset/agent-collector --timeout=120s

kubectl apply -f /tmp/otel-12-lab/03-instrumentation.yaml

kubectl apply -f /tmp/otel-12-lab/04-pyapp.yaml
kubectl -n demo rollout status deploy/pyapp --timeout=120s

bash tests/validate.sh
```

## Respuestas a las preguntas de reflexión

1. **¿Por qué el `Instrumentation` apunta al agent, no al gateway?** Porque `k8sattributes` necesita identificar el Pod por **IP source**; cuando la app envía al agent local (mismo nodo), esa IP es la del Pod. Si enviase al gateway (otro nodo) a través de un `Service` ClusterIP, la IP podría ser NATeada y el `pod_association` fallaría.
2. **`k8sattributes` en el gateway: qué puede fallar.** NAT por `kube-proxy` (iptables/ipvs/NFTables) puede reescribir la source. En clusters con CNIs que preservan la source IP (Cilium con `kubeProxyReplacement`, por ejemplo) sí funciona, pero no es portable.
3. **Borrar `deploy/gateway-collector`**: el Operator lo recrea en segundos (reconciliación). Borrar el **CR** `otelcol/gateway`: desaparece todo (Deployment, ConfigMap, SA) via `ownerReferences`.
4. **Cambios que disparan rollout sin tocar el workload**: cualquier cambio en `spec.config`, `spec.image`, `spec.resources`, `spec.env`. El Operator renderiza un ConfigMap con hash nuevo → el Deployment lo monta → rolling update.
5. **Preferir Helm**: 1-2 Collectors sin auto-inject ni TA, equipos muy pequeños, o entornos donde no se puede introducir cert-manager + un Operator más. El Operator paga su overhead cuando hay múltiples CRs y auto-inject.
