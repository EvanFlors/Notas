# Recursos — argo-09

## Documentación oficial

- External Secrets Operator — https://external-secrets.io/
- Sealed Secrets — https://github.com/bitnami-labs/sealed-secrets
- SOPS — https://github.com/getsops/sops
- KSOPS (Kustomize plugin) — https://github.com/viaduct-ai/kustomize-sops
- age — https://github.com/FiloSottile/age
- Secrets Store CSI Driver — https://secrets-store-csi-driver.sigs.k8s.io/
- Vault Agent Injector — https://developer.hashicorp.com/vault/docs/platform/k8s/injector
- Argo CD Config Management Plugins (CMPs) — https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/

## Providers de ESO (selección)

- AWS Secrets Manager — https://external-secrets.io/latest/provider/aws-secrets-manager/
- GCP Secret Manager — https://external-secrets.io/latest/provider/google-secrets-manager/
- Azure Key Vault — https://external-secrets.io/latest/provider/azure-key-vault/
- HashiCorp Vault — https://external-secrets.io/latest/provider/hashicorp-vault/
- Fake (tests) — https://external-secrets.io/latest/provider/fake/

## Lecturas

- OpenGitOps — https://opengitops.dev/
- Kubernetes `EncryptionConfiguration` — https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- "Securing GitOps pipelines with ESO" — blogs oficiales de External Secrets.
- CNCF whitepaper sobre secret management (buscar edición más reciente).

## Herramientas útiles

- `gitleaks` / `trufflehog` para detectar secretos filtrados accidentalmente al repo.
- `cosign` + Kyverno para cerrar la cadena DevSecOps (ver módulo `argo-10` y curso `k8s`).
