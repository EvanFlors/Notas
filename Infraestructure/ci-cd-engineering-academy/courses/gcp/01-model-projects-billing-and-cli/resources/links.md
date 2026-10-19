# Recursos — gcp-01

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing cambian).

## Oficiales (Google Cloud)

- **Resource hierarchy overview**: `https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy`
- **Creating and managing projects**: `https://cloud.google.com/resource-manager/docs/creating-managing-projects`
- **Creating and managing folders**: `https://cloud.google.com/resource-manager/docs/creating-managing-folders`
- **Billing accounts overview**: `https://cloud.google.com/billing/docs/concepts`
- **Modify a project's Cloud Billing account**: `https://cloud.google.com/billing/docs/how-to/modify-project`

## APIs y Service Usage

- **Enabling and disabling services**: `https://cloud.google.com/service-usage/docs/enable-disable`
- **Service Usage API**: `https://cloud.google.com/service-usage/docs`

## `gcloud` CLI

- **Install the gcloud CLI**: `https://cloud.google.com/sdk/docs/install`
- **gcloud config configurations**: `https://cloud.google.com/sdk/docs/configurations`
- **gcloud config properties**: `https://cloud.google.com/sdk/docs/properties`
- **Reference: `gcloud auth login`**: `https://cloud.google.com/sdk/gcloud/reference/auth/login`
- **Reference: `gcloud auth application-default login`**: `https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login`

## ADC (Application Default Credentials)

- **How ADC works**: `https://cloud.google.com/docs/authentication/application-default-credentials`
- **Set up ADC for a local development environment**: `https://cloud.google.com/docs/authentication/provide-credentials-adc`
- **Service account impersonation**: `https://cloud.google.com/iam/docs/service-account-impersonation`
- **Why not to use service account keys**: `https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys`

## Budgets y FinOps

- **Create, edit, or delete budgets and alerts**: `https://cloud.google.com/billing/docs/how-to/budgets`
- **Programmatic budget notifications (Pub/Sub)**: `https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications`
- **Hard-stop pattern (unlink billing on threshold)**: `https://cloud.google.com/billing/docs/how-to/notify`
- **Billing export to BigQuery**: `https://cloud.google.com/billing/docs/how-to/export-data-bigquery`

## Labels y Tags

- **Creating and managing labels**: `https://cloud.google.com/resource-manager/docs/creating-managing-labels`
- **Tags overview (IAM-aware)**: `https://cloud.google.com/resource-manager/docs/tags/tags-overview`

## Para contexto AWS -> GCP

- **Google Cloud for AWS professionals**: `https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison`

## Checklist de verificacion requerida en Fase 4

- Comandos `gcloud alpha billing budgets *` (si han salido de `alpha`).
- Nombres actuales de APIs (`cloudresourcemanager.googleapis.com`, `iamcredentials.googleapis.com`, etc. — raramente cambian pero conviene verificar).
- Vigencia del esquema de `BudgetFilter` (han añadido filtros por `services`, `credit_types`).
- Estado del comando `gcloud auth application-default login --impersonate-service-account` (es GA en 2024+; verificar).
- Si existe ya un flag `--no-browser` oficial para flujos sin interfaz grafica (p. ej. SSH remoto).
