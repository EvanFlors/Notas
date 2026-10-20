# EKS — walkthrough (plan-only)

Este módulo **no se aplica** en el aula. Se usa para que el estudiante
corra `init && validate && plan` e inspeccione la forma del recurso.

```bash
terraform init -backend=false
terraform validate
terraform plan -var 'subnet_ids=["subnet-DUMMY-a","subnet-DUMMY-b"]' -out=tfplan
terraform show tfplan | less
```

Qué pediría la nube si corrieras `apply` (no lo hagas):

- ~15 min de aprovisionamiento del control plane.
- ~5 min adicionales para el managed node group.
- ~$73/mes solo por el control plane EKS, más EC2 (nodos) y data egress.

Si de verdad quisieras aplicar: usa el módulo oficial
`terraform-aws-modules/eks/aws` que trae IRSA, add-ons y networking.
Este stack es mínimo intencionalmente, para enseñar los primitivos.
