# Solución — otel-09-01

Mira `agent.yaml` y `gateway.yaml`: son equivalentes a `starter/` con los `# TODO` completados. Puedes aplicarlos directamente para comparar.

```bash
# Aplicar la solución
kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f gateway.yaml
kubectl -n observability rollout status deploy/otel-gateway --timeout=120s
kubectl apply -f agent.yaml
kubectl -n observability rollout status ds/otel-agent --timeout=120s
```

No consultes esta carpeta hasta haber intentado tus propias ediciones.
