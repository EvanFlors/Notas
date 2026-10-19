# Starter — aws-11-01-provision-eks-and-run-app

Esta actividad es **architecture + hands-on local**: escribes Terraform y YAML (sin desplegar en AWS) y pruebas los manifiestos K8s en un cluster `kind`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-11-01/{terraform,eksctl,k8s,docs}
   cd /tmp/aws-11-01
   ```
3. Escribe los 5 entregables:
   - `terraform/main.tf`
   - `eksctl/cluster.yaml`
   - `k8s/app.yaml`
   - `docs/EKS_PLAN.md`
   - `docs/ADR.md`
4. Valida sintaxis Terraform:
   ```bash
   cd /tmp/aws-11-01/terraform && terraform init -backend=false && terraform validate
   ```
5. (Opcional) Valida `eksctl`:
   ```bash
   eksctl create cluster --config-file=/tmp/aws-11-01/eksctl/cluster.yaml --dry-run
   ```
6. Levanta `kind` y aplica los manifiestos:
   ```bash
   kind create cluster --name aws-11-demo
   kubectl --context kind-aws-11-demo apply -f /tmp/aws-11-01/k8s/app.yaml
   ```
7. Corre el validador:
   ```bash
   bash <ruta-repo>/courses/aws/11-eks-in-depth/activities/01-provision-eks-and-run-app/tests/validate.sh /tmp/aws-11-01
   ```
8. Compara tu trabajo con `../solution/REFERENCE.md`.
9. Limpia:
   ```bash
   kind delete cluster --name aws-11-demo
   rm -rf /tmp/aws-11-01
   ```

> **Recordatorio:** nunca uses un account id real en los ejemplos. `123456789012` es el placeholder canónico de AWS.
