# Starter — gcp-07-01-gke-standard-vs-autopilot-tf-plan-and-adr

Actividad independiente: produces 2 archivos Terraform + 1 ADR Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../../examples/01-gke-autopilot-vs-standard/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-07-01-gke-tf-adr/terraform/standard
   mkdir -p /tmp/gcp-07-01-gke-tf-adr/terraform/autopilot
   cd /tmp/gcp-07-01-gke-tf-adr
   ```
3. Copia los esqueletos de `starter/terraform/standard/main.tf` y `starter/terraform/autopilot/main.tf` y complétalos.
4. (Opcional) Valida con Terraform:
   ```bash
   cd terraform/standard && terraform init -backend=false && terraform validate && cd -
   cd terraform/autopilot && terraform init -backend=false && terraform validate && cd -
   ```
5. Escribe `ADR-GKE-MODE.md` con las 6 secciones (Estado, Contexto, Decisión, Consecuencias, Alternativas + encabezado ADR).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/07-gke-and-autopilot/activities/01-gke-standard-vs-autopilot-tf-plan-and-adr/tests/validate.sh /tmp/gcp-07-01-gke-tf-adr
   ```
7. Compara con `../solution/REFERENCE.md`.

## Nota

**No ejecutes `terraform plan` ni `terraform apply`**: no hay credenciales GCP y no queremos coste. El validador cubre lo necesario con `terraform validate` (que no llama a GCP).

**Usa placeholders de project ID** (`my-project-123`, nunca un ID real).
