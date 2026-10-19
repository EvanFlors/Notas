# Recursos — gcp-06 KMS y Secret Manager

## Documentación oficial

- Cloud KMS — overview: https://cloud.google.com/kms/docs
- Cloud KMS — key rotation: https://cloud.google.com/kms/docs/rotating-keys
- Cloud KMS — CMEK en servicios: https://cloud.google.com/kms/docs/cmek
- Cloud KMS — envelope encryption: https://cloud.google.com/kms/docs/envelope-encryption
- Cloud HSM: https://cloud.google.com/kms/docs/hsm
- Cloud EKM: https://cloud.google.com/kms/docs/ekm
- Secret Manager — overview: https://cloud.google.com/secret-manager/docs
- Secret Manager — rotation: https://cloud.google.com/secret-manager/docs/rotation-recommender
- Cloud Run — mounting secrets: https://cloud.google.com/run/docs/configuring/services/secrets

## Terraform

- Resource `google_kms_key_ring`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring
- Resource `google_kms_crypto_key`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key
- Resource `google_secret_manager_secret`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
- Resource `google_secret_manager_secret_version`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version

## Lecturas y referencias cruzadas

- `aws-09-kms-secrets-manager-parameter-store` — equivalente AWS (modelo mental de comparación).
- `gcp-02-iam-bindings-deny-policies-and-service-accounts` — necesario para entender bindings y service agents.
- Python `cryptography` — primitives usadas en el demo: https://cryptography.io/en/latest/hazmat/primitives/aead/
- NIST SP 800-57 — key management guidelines (fundamento del rotation period).
