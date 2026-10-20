# GKE Autopilot — walkthrough (plan-only)

```bash
terraform init -backend=false
terraform validate
terraform plan -out=tfplan
terraform show tfplan | less
```

Autopilot cobra por pod-second, no por nodo. Idle cuesta ~$73/mes solo
por el control plane regional. Con carga real, el costo depende de
requests de CPU/memoria de tus pods, no de nodos.

Workload Identity viene habilitado por defecto en Autopilot: tus pods
asumen una `google_service_account` sin keys estaticas.
