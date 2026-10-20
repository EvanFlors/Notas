# AKS — walkthrough (plan-only)

```bash
terraform init -backend=false
terraform validate
terraform plan -out=tfplan
terraform show tfplan | less
```

Tier Free del control plane AKS cuesta $0 (sin SLA). Pagas los nodos:
2× Standard_B2s ~ $60/mes. Workload Identity: `SystemAssigned` da una
identidad administrada al cluster; para pods, se habilita OIDC +
workload-identity por separado (fuera de scope aqui).
