# Starter — gcp-02-02

## 1. Preparación

```
mkdir -p /tmp/gcp-02-impersonate
```

Edita ahí tus dos archivos:

- `/tmp/gcp-02-impersonate/token-creator-binding.yaml`
- `/tmp/gcp-02-impersonate/IMPERSONATION-WALKTHROUGH.md`

Valida:

```
bash tests/validate.sh /tmp/gcp-02-impersonate
```

## 2. Esqueletos (COMPLÉTALOS, no los copies tal cual)

### `token-creator-binding.yaml`

```yaml
# Binding aplicado SOBRE la SA destino deployer@acme-prod.iam.gserviceaccount.com.
# En Terraform: google_service_account_iam_binding con
#   service_account_id = "projects/acme-prod/serviceAccounts/deployer@acme-prod.iam.gserviceaccount.com"
#   role               = "roles/iam.serviceAccountTokenCreator"
#   members            = [...]

bindings:
  - role: roles/iam.serviceAccountTokenCreator
    members:
      # TODO: grupo humano autorizado a impersonar
```

### `IMPERSONATION-WALKTHROUGH.md`

```markdown
# Flujo de impersonation

TODO: pasos numerados con los comandos gcloud concretos (auth login,
--impersonate-service-account, API iamcredentials.googleapis.com,
role iam.serviceAccountTokenCreator).

# Por que NO SA key

TODO: tres razones materiales (expiracion, rotacion, auditabilidad)
+ mencion de la org policy iam.disableServiceAccountKeyCreation
+ mencion de Workload Identity Federation como alternativa correcta.

# Auditoria

TODO: como aparece el humano y la SA en los audit logs,
mencionando serviceAccountDelegationInfo y principalEmail.
```

## 3. Validacion

```
bash tests/validate.sh /tmp/gcp-02-impersonate
```

Debe terminar en `OK:`.
