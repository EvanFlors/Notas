# sec-13 — Recursos y referencias

## HashiCorp Vault

- Documentación oficial — https://developer.hashicorp.com/vault/docs
- `kv-v2` secrets engine — https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
- `database` secrets engine (dynamic creds) — https://developer.hashicorp.com/vault/docs/secrets/databases
- `transit` secrets engine (encryption as a service) — https://developer.hashicorp.com/vault/docs/secrets/transit
- `pki` secrets engine — https://developer.hashicorp.com/vault/docs/secrets/pki
- Kubernetes auth method — https://developer.hashicorp.com/vault/docs/auth/kubernetes
- AppRole auth method — https://developer.hashicorp.com/vault/docs/auth/approle
- OIDC/JWT auth method — https://developer.hashicorp.com/vault/docs/auth/jwt
- Audit devices — https://developer.hashicorp.com/vault/docs/audit
- Vault Agent (sidecar / injector) — https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent

## External Secrets Operator (ESO)

- Documentación oficial — https://external-secrets.io/
- Chart Helm — https://github.com/external-secrets/external-secrets/tree/main/deploy/charts/external-secrets
- Provider Vault — https://external-secrets.io/latest/provider/hashicorp-vault/
- Provider AWS Secrets Manager — https://external-secrets.io/latest/provider/aws-secrets-manager/
- Provider GCP Secret Manager — https://external-secrets.io/latest/provider/google-secrets-manager/
- Provider Azure Key Vault — https://external-secrets.io/latest/provider/azure-key-vault/
- `ClusterSecretStore` CRD — https://external-secrets.io/latest/api/clustersecretstore/
- `ExternalSecret` CRD — https://external-secrets.io/latest/api/externalsecret/

## Alternativas (y por qué ESO suele ganar a escala)

- Secrets Store CSI Driver — https://secrets-store-csi-driver.sigs.k8s.io/
- Vault Agent Injector (webhook) — https://developer.hashicorp.com/vault/docs/platform/k8s/injector
- Sealed Secrets (bitnami) — https://github.com/bitnami-labs/sealed-secrets
- SOPS + age — https://github.com/getsops/sops

## Workload Identity

- AWS IRSA — https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- AWS EKS Pod Identity (más reciente) — https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- GKE Workload Identity — https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity
- Azure Workload Identity (reemplaza AAD Pod Identity) — https://azure.github.io/azure-workload-identity/docs/

## Audit & compliance

- Vault audit log format — https://developer.hashicorp.com/vault/tutorials/monitoring/audit
- CIS Vault Benchmark — https://developer.hashicorp.com/vault/tutorials/operations/production-hardening
- OWASP Secrets Management Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

## Tooling necesario para los ejemplos y el capstone

- `docker` ≥ 24.0 — https://docs.docker.com/engine/install/
- `kind` ≥ 0.22 — https://kind.sigs.k8s.io/docs/user/quick-start/
- `kubectl` ≥ 1.29 — https://kubernetes.io/docs/tasks/tools/
- `helm` ≥ 3.14 — https://helm.sh/docs/intro/install/
- `vault` CLI ≥ 1.15 — https://developer.hashicorp.com/vault/install

## Lecturas recomendadas

- *"Secret-less architectures" (HashiCorp blog, 2021)* — concepto que da nombre a este módulo.
- *"How we killed the shared password" (Shopify engineering, 2022)* — caso real de migración desde `.env`.
- *"The 10 Immutable Laws of Security"* — recordatorio clásico de por qué los secretos **nunca** se almacenan sin cifrar.
