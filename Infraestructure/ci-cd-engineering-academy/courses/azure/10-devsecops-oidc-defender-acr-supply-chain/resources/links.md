# Recursos — az-10

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso (nombres, portales y pricing cambian).

## Oficiales (Microsoft)

- **Workload Identity Federation (overview)**: `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation`
- **Configure a federated identity credential**: `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust`
- **GitHub Actions + Azure OIDC**: `https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect`
- **Azure Container Registry overview**: `https://learn.microsoft.com/en-us/azure/container-registry/`
- **ACR SKUs & features**: `https://learn.microsoft.com/en-us/azure/container-registry/container-registry-skus`
- **ACR Private Link**: `https://learn.microsoft.com/en-us/azure/container-registry/container-registry-private-link`
- **ACR repository-scoped tokens**: `https://learn.microsoft.com/en-us/azure/container-registry/container-registry-repository-scoped-permissions`
- **Microsoft Defender for Cloud**: `https://learn.microsoft.com/en-us/azure/defender-for-cloud/`
- **Defender for Containers**: `https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-introduction`
- **Microsoft Sentinel**: `https://learn.microsoft.com/en-us/azure/sentinel/`
- **Deployment Stacks**: `https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks`

## GitHub Actions

- **`azure/login` action**: `https://github.com/Azure/login`
- **GitHub OIDC token claims reference**: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
- **`permissions: id-token: write`**: `https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs`

## Supply chain / cosign / Ratify / Kyverno

- **sigstore / cosign**: `https://docs.sigstore.dev/cosign/overview/`
- **Keyless signing**: `https://docs.sigstore.dev/cosign/signing/overview/#keyless-signing`
- **Rekor transparency log**: `https://docs.sigstore.dev/logging/overview/`
- **Ratify (CNCF)**: `https://ratify.dev/docs/what-is-ratify`
- **Kyverno image verification**: `https://kyverno.io/docs/writing-policies/verify-images/`
- **AKS image verification with Ratify**: `https://learn.microsoft.com/en-us/azure/aks/image-integrity`

## Terraform providers relevantes

- **`azuread` provider — federated identity credential**: `https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential`
- **`azurerm` provider — ACR**: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry`
- **`azurerm` provider — Security Center Pricing**: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/security_center_subscription_pricing`

## Lecturas y charlas

- Blog: "GitHub Actions OIDC with Azure — step by step" (Microsoft DevBlogs, varias ediciones).
- Charla KubeCon: "Securing software supply chain with sigstore + Ratify".
- Microsoft Learn Path: "Secure your DevOps pipeline on Azure".

## Checklist de verificacion requerida en Fase 4

- Formato actual del `subject` claim para GitHub Actions OIDC (Microsoft documenta patrones nuevos periodicamente).
- Features agregadas al plan **Defender for Containers** (agentless, Kubernetes-native scanner, etc.).
- Estado GA/Preview de **AKS Image Integrity** (feature flag basada en Ratify).
- Soporte Terraform para **Deployment Stacks** como recurso nativo (hoy via `azapi`).
- Deprecacion de **ACR Content Trust clasico (Notary v1)** y migracion recomendada a **Notation (Notary v2)** o cosign.
- Pricing actual de ACR Premium y de Defender for Containers (vCPU + imagen).
