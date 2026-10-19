# Starter — gcp-02-01

## 1. Preparación

```
mkdir -p /tmp/gcp-02-lpp
```

Edita ahí tus tres archivos:

- `/tmp/gcp-02-lpp/iam-bindings.yaml`
- `/tmp/gcp-02-lpp/deny-policy.yaml`
- `/tmp/gcp-02-lpp/README-INTENT.md`

Cuando creas tener algo defendible, ejecuta el validador:

```
bash tests/validate.sh /tmp/gcp-02-lpp
```

## 2. Esqueletos mínimos (COMPLÉTALOS, no los copies tal cual)

### `iam-bindings.yaml`

```yaml
# Bindings para la SA del workload receipts-processor
# Cada entry representa UN binding sobre UN recurso (anotado en el comentario).
# En Terraform/gcloud real, estos bindings se aplicarian con
# gcloud storage buckets add-iam-policy-binding gs://... --role=... --member=...
# o con google_storage_bucket_iam_binding en Terraform.

bindings:
  # TODO: binding sobre gs://acme-prod-receipts-raw
  #   role: ??? (predefined, lectura de objetos)
  #   members: [serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com]

  # TODO: binding sobre gs://acme-prod-receipts-processed
  #   role: ??? (predefined, creacion de objetos)
  #   members: [serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com]

  # TODO: binding sobre projects/acme-prod/topics/receipts-events
  #   role: ??? (predefined, publicar en Pub/Sub)
  #   members: [serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com]
```

### `deny-policy.yaml`

```yaml
# Deny policy adjuntada al folder prod (o al project acme-prod) para
# vetar el borrado de los buckets de recibos, con excepcion break-glass.

name: policies/cloudresourcemanager.googleapis.com%2Ffolders%2F000000000000/denypolicies/no-receipts-bucket-delete
displayName: TODO describe

rules:
  - description: TODO describe la regla
    denyRule:
      deniedPrincipals:
        - principalSet://goog/public:all
      exceptionPrincipals:
        # TODO: incluye el grupo break-glass con prefijo principalSet://goog/group/
      deniedPermissions:
        # TODO: usa NOMBRES CUALIFICADOS, no "storage.buckets.delete"
      denialCondition:
        title: always
        expression: "true"
```

### `README-INTENT.md`

```markdown
# iam-bindings — intencion

TODO: por cada binding, por que ese role predefinido y no otro, y por que no basic (owner/editor/viewer).

# deny-policy — intencion

TODO: que veta, a quien, por que el break-glass y como se audita su uso.
```

## 3. Validacion

```
bash tests/validate.sh /tmp/gcp-02-lpp
```

Debe terminar en `OK:`. Si no, lee el output — cada FAIL indica una comprobacion concreta.
