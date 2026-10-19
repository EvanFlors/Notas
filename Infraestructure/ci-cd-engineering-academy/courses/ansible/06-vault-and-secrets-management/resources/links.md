# Recursos — ans-06

Referencias oficiales y lecturas complementarias. **Verificar vigencia en Fase 4** del programa.

## Oficiales (Ansible)

- **Protecting sensitive data with Ansible vault**: `https://docs.ansible.com/ansible/latest/vault_guide/index.html`
- **`ansible-vault` command reference**: `https://docs.ansible.com/ansible/latest/cli/ansible-vault.html`
- **Vault IDs y múltiples passwords**: `https://docs.ansible.com/ansible/latest/vault_guide/vault_managing_passwords.html`
- **`no_log` task keyword**: `https://docs.ansible.com/ansible/latest/reference_appendices/logging.html`
- **`amazon.aws.aws_secret` lookup**: `https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_secret_lookup.html`
- **`community.hashi_vault` collection**: `https://docs.ansible.com/ansible/latest/collections/community/hashi_vault/`

## SOPS

- **Mozilla SOPS repo**: `https://github.com/getsops/sops`
- **SOPS README y guía**: `https://github.com/getsops/sops#readme`
- **`community.sops` collection**: `https://docs.ansible.com/ansible/latest/collections/community/sops/`

## External Secrets Operator

- **External Secrets Operator (K8s)**: `https://external-secrets.io/`
- **Provider list (AWS SM, Vault, GCP SM, Azure KV, 1Password, ...)**: `https://external-secrets.io/latest/provider/aws-secrets-manager/`

## Secret managers nativos

- **AWS Secrets Manager**: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/`
- **HashiCorp Vault**: `https://developer.hashicorp.com/vault/docs`
- **Azure Key Vault**: `https://learn.microsoft.com/azure/key-vault/`
- **GCP Secret Manager**: `https://cloud.google.com/secret-manager/docs`

## Lecturas

- **"Secrets management with Ansible"** (blog oficial Red Hat, varias ediciones).
- **"Why ansible-vault is not enough at scale"** — buscar charlas de AnsibleFest sobre integración con secret managers.
- **12-factor app: config**: `https://12factor.net/config` (ni vault ni SM — pero el principio de "config en el entorno" aplica).
