# Starter — aws-16-01-full-oidc-pipeline-no-keys

Este mini-proyecto es local. **No se despliega nada en AWS.** No hay plantilla ejecutable: tus entregables son 4 archivos escritos por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-16-01-oidc/terraform
   mkdir -p /tmp/aws-16-01-oidc/.github/workflows
   cd /tmp/aws-16-01-oidc
   ```
3. Escribe los 4 entregables:
   - `terraform/main.tf` — OIDC provider + IAM Role con trust policy pinneada.
   - `terraform/variables.tf` — variables (`github_repo`, `github_ref`, `role_name`).
   - `terraform/outputs.tf` — output `role_arn`.
   - `.github/workflows/deploy.yml` — workflow con `permissions.id-token: write` a nivel de job y `aws-actions/configure-aws-credentials@v4`.
   - `ADR-oidc-sub-pinning.md` — ADR en formato Context/Decision/Consequences/Alternatives.
4. Valida localmente:
   ```bash
   cd terraform
   terraform init -backend=false
   terraform validate
   cd ..
   bash <ruta-repo>/courses/aws/16-devsecops-on-aws/activities/01-full-oidc-pipeline-no-keys/tests/validate.sh /tmp/aws-16-01-oidc
   ```
5. Compara con `../solution/REFERENCE.md`.

> **Importante:** el validador comprueba **estructura y ausencia de anti-patrones**, no semántica profunda. La defensa del ADR la revisas tú contra la referencia.

> **Credenciales AWS**: no se necesitan. `terraform init -backend=false` y `terraform validate` no llaman a AWS. **No ejecutes `terraform plan` ni `terraform apply`.**
