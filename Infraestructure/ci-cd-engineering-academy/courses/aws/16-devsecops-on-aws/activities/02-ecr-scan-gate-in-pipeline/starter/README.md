# Starter — aws-16-02-ecr-scan-gate-in-pipeline

Esta actividad es local. **No se despliega nada en AWS.** No hay plantilla ejecutable: tus entregables son 4 archivos escritos por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-16-02-ecr/terraform
   mkdir -p /tmp/aws-16-02-ecr/.github/workflows
   cd /tmp/aws-16-02-ecr
   ```
3. Escribe los 4 entregables:
   - `terraform/main.tf` — repositorio ECR con `scan_on_push`, `IMMUTABLE`, KMS, lifecycle policy.
   - `terraform/variables.tf` — variables (`repo_name`, `kms_key_arn`, `max_untagged_images`, `aws_region`).
   - `terraform/outputs.tf` — output `repository_url`.
   - `.github/workflows/build-scan-gate.yml` — workflow que construye, publica, espera scan y falla si hay `CRITICAL`/`HIGH`.
   - `ADR-ecr-scanning-tier.md` — ADR en formato Context/Decision/Consequences/Alternatives.
4. Valida localmente:
   ```bash
   cd terraform
   terraform init -backend=false
   terraform validate
   cd ..
   bash <ruta-repo>/courses/aws/16-devsecops-on-aws/activities/02-ecr-scan-gate-in-pipeline/tests/validate.sh /tmp/aws-16-02-ecr
   ```
5. Compara con `../solution/REFERENCE.md`.

> **Importante:** el validador comprueba **estructura y ausencia de anti-patrones**, no semantica profunda del gate (no corre `docker build` ni llama a ECR). La defensa del ADR y el flujo del gate los revisas tu contra la referencia.

> **Credenciales AWS**: no se necesitan. `terraform init -backend=false` y `terraform validate` no llaman a AWS. **No ejecutes `terraform plan` ni `terraform apply`.** El workflow tampoco se ejecuta: su validacion es estructural.
