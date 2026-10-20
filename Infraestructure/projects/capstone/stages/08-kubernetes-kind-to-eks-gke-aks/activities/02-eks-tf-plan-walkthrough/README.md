# Actividad 02 — Terraform plan de EKS/GKE/AKS (independent)

## Objetivo

Correr `terraform init -backend=false && terraform validate && terraform plan`
en las tres nubes y producir `WALKTHROUGH.md` dentro de esta carpeta,
respondiendo:

1. ¿Cuantos recursos planea crear cada nube?
2. ¿Que recurso tarda mas en provisionar y por que?
3. ¿Cuanto costaria mantener el cluster idle 24h?
4. ¿Que mecanismo usa cada nube para que un pod obtenga credenciales
   sin keys estaticas? (IRSA / Workload Identity / Workload Identity +
   OIDC)
5. ¿Cual elegirias para el capstone y por que? (anticipa stage 9).

**No apliques nada.** Guarda los planes:

```bash
cd ../../terraform/aws/eks
terraform init -backend=false && terraform validate
terraform plan -var 'subnet_ids=["subnet-DUMMY-a","subnet-DUMMY-b"]' -out=tfplan
# repite para gcp/gke y azure/aks
```

## Validacion

```bash
bash tests/validate.sh
```
