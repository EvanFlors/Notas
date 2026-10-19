# Recursos — gcp-09

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing pueden cambiar).

## Oficiales (Google Cloud)

- **Resource Manager (jerarquía)**: `https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy`
- **Organization Policy Service**: `https://cloud.google.com/resource-manager/docs/organization-policy/overview`
- **Catalog de constraints**: `https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints`
- **Custom constraints (CEL)**: `https://cloud.google.com/resource-manager/docs/organization-policy/creating-managing-custom-constraints`
- **Cloud Identity (Free vs Premium)**: `https://cloud.google.com/identity/docs/overview`
- **Cloud Identity Groups API**: `https://cloud.google.com/identity/docs/concepts/overview-groups`
- **Billing Account y Essential Contacts**: `https://cloud.google.com/billing/docs` ; `https://cloud.google.com/resource-manager/docs/managing-notification-contacts`

## IAM y Deny Policies

- **IAM Allow Policies**: `https://cloud.google.com/iam/docs/policies`
- **IAM Deny Policies**: `https://cloud.google.com/iam/docs/deny-overview`
- **IAM Conditions (CEL)**: `https://cloud.google.com/iam/docs/conditions-overview`

## VPC Service Controls

- **VPC-SC overview**: `https://cloud.google.com/vpc-service-controls/docs/overview`
- **Perimeters y configuración**: `https://cloud.google.com/vpc-service-controls/docs/service-perimeters`
- **Access Context Manager (access levels)**: `https://cloud.google.com/access-context-manager/docs`
- **Dry-run mode** (recomendado antes de enforce): `https://cloud.google.com/vpc-service-controls/docs/dry-run-mode`

## Security Command Center

- **SCC Standard vs Premium vs Enterprise**: `https://cloud.google.com/security-command-center/docs/service-tiers`
- **Overview**: `https://cloud.google.com/security-command-center/docs/overview`

## Terraform / IaC

- **terraform-google-modules/project-factory**: `https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest`
- **terraform-google-modules/folders**: `https://registry.terraform.io/modules/terraform-google-modules/folders/google/latest`
- **Google Cloud Enterprise Foundation Blueprint**: `https://cloud.google.com/architecture/security-foundations`

## Lecturas y charlas

- Google Cloud Next — "Landing Zones at scale with Organization Policies". Buscar la edición más reciente en YouTube.
- Blog: "Best practices for enterprise organizations" (Google Cloud Blog, actualizado periódicamente).
- Blog: "Separation of duties with Cloud Identity groups" (varias ediciones).
- Whitepaper: "Google Cloud security foundations guide".

## Para el curso previo (contexto)

- Si no completaste `gcp-02`, al menos lee:
  - IAM allow policy evaluation.
  - Service Accounts e impersonation (`roles/iam.serviceAccountTokenCreator`).

## Checklist de verificación requerida en Fase 4

- Nombre y estado del catálogo de **constraints** oficiales (crece con el tiempo; verificar los 4 del baseline del módulo).
- Estado de **Custom constraints** (resourceTypes soportados).
- Pricing y features de **Security Command Center** (Standard es gratis para una org; Premium y Enterprise se cobran).
- Estado de **IAM Deny Policies** (GA, atributos permitidos, condition keys).
- **VPC-SC** compatibilidad con cada servicio en `restrictedServices` (lista crece).
- **Cloud Identity Free vs Premium** diferencias (feature flags).
- **Workload Identity Federation** desde GitHub Actions (atributos recomendados, templates vigentes) — relevante para `gcp-10`.
