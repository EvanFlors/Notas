# Recursos — sec-02

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia (los enlaces y los estados cambian).

## Principios y guías de referencia

- **OWASP Secrets Management Cheat Sheet**: `https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html`
- **NIST SP 800-57 Part 1 — Recommendation for Key Management (General)**: `https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final`
- **NIST SP 800-63B — Digital Identity (authenticator lifecycle)**: `https://pages.nist.gov/800-63-3/sp800-63b.html`
- **CIS Benchmarks (Cloud/Kubernetes/AWS/GCP)**: `https://www.cisecurity.org/cis-benchmarks`
- **CSA Cloud Controls Matrix (CCM)** — dominio `IVS`/`IAM` para secretos: `https://cloudsecurityalliance.org/research/cloud-controls-matrix/`

## Secret managers / vaults

- **HashiCorp Vault**: `https://developer.hashicorp.com/vault/docs`
  - Dynamic secrets: `https://developer.hashicorp.com/vault/docs/secrets/databases`
  - Transit (encryption as a service): `https://developer.hashicorp.com/vault/docs/secrets/transit`
- **AWS Secrets Manager**: `https://docs.aws.amazon.com/secretsmanager/`
- **AWS KMS**: `https://docs.aws.amazon.com/kms/`
- **GCP Secret Manager**: `https://cloud.google.com/secret-manager/docs`
- **GCP Cloud KMS**: `https://cloud.google.com/kms/docs`
- **Azure Key Vault**: `https://learn.microsoft.com/azure/key-vault/`

## Short-lived credentials / workload identity

- **GitHub Actions OIDC**: `https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
- **AWS STS (AssumeRole, GetFederationToken)**: `https://docs.aws.amazon.com/STS/latest/APIReference/welcome.html`
- **AWS IRSA (IAM Roles for Service Accounts, EKS)**: `https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html`
- **GCP Workload Identity Federation**: `https://cloud.google.com/iam/docs/workload-identity-federation`
- **Azure Workload Identity**: `https://learn.microsoft.com/azure/aks/workload-identity-overview`
- **Kubernetes ServiceAccount Token Volume Projection**: `https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection`

## Rotación y gestión de claves

- **AWS Secrets Manager Rotation**: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html`
- **AWS KMS Key Rotation**: `https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html`
- **cert-manager (ACME + rotación de TLS en K8s)**: `https://cert-manager.io/docs/`
- **SSH CA + certificados de corta vida** (Teleport, HashiCorp Vault SSH): `https://developer.hashicorp.com/vault/docs/secrets/ssh`

## Signing keyless (relación con `sec-09`)

- **Sigstore**: `https://www.sigstore.dev/`
- **cosign**: `https://docs.sigstore.dev/cosign/overview/`
- **Fulcio** (CA efímera): `https://docs.sigstore.dev/certificate_authority/overview/`
- **Rekor** (transparency log): `https://docs.sigstore.dev/logging/overview/`

## Incidentes relevantes para casos de estudio

- **Uber 2016** — AWS keys hardcoded en repo privado (acceso vía GitHub comprometido).
- **Codecov 2021** — bash uploader comprometido → exfiltración de env vars con secretos de cliente.
- **CircleCI 2023** — tokens de sesión robados → acceso a secrets de proyectos de cliente; obligó rotación masiva.
- **tj-actions/changed-files 2025** — compromise de un action de GitHub Actions ampliamente usado; exfiltró secretos de entornos de muchos repos.
- **xz-utils 2024** — supply chain attack (relacionado con `sec-01`, pero útil contexto aquí).

## Herramientas (vista previa; se usan en módulos siguientes)

- **gitleaks** (`sec-04`): `https://github.com/gitleaks/gitleaks`
- **trufflehog** (`sec-04`): `https://github.com/trufflesecurity/trufflehog`
- **External Secrets Operator** (`sec-13`): `https://external-secrets.io/`
- **Secrets Store CSI Driver** (`sec-13`): `https://secrets-store-csi-driver.sigs.k8s.io/`
- **SOPS** (puente para config files cifrados): `https://github.com/getsops/sops`

## Para el curso previo (contexto)

- Si no completaste `sec-01`, al menos lee:
  - `courses/devsecops/01-principles-threat-modeling-and-supply-chain-overview/README.md`

## Checklist de verificación requerida en Fase 4

- Estado actual de **GitHub Actions OIDC** y de los `aws-actions/configure-aws-credentials` (versión y features).
- Estado de **IRSA** en EKS y de **EKS Pod Identity** (preferencia operacional vigente).
- Versión y features actuales de **HashiCorp Vault** (dynamic DB engines soportados, Transit mejoras).
- Versión y features actuales de **External Secrets Operator** y **Secrets Store CSI Driver**.
- Estado de **Sigstore / cosign keyless** y UX vigente de `cosign verify`.
- Incidentes nuevos relevantes para actualizar casos de estudio (p. ej. actions comprometidos, cloud key leaks).
