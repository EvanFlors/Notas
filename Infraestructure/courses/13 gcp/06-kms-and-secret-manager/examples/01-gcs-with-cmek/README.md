# Ejemplo 01 — Bucket GCS con CMEK (lectura y análisis)

> **No se ejecuta contra GCP.** Es un ejemplo *comentado* para interiorizar el patrón.

## Objetivo

Mostrar la anatomía mínima de un bucket Cloud Storage protegido con una **Customer-Managed Encryption Key** y por qué el binding al **service agent** de GCS es imprescindible.

## Terraform anotado

```hcl
# Variables de ejemplo. No corresponden a un project real.
variable "project_id"     { default = "demo-cmek-example" }
variable "project_number" { default = "000000000000" }   # placeholder, no real
variable "region"         { default = "europe-west1" }

# 1) Keyring regional. No se puede borrar nunca una vez creado.
resource "google_kms_key_ring" "data" {
  name     = "kr-data"
  location = var.region
  project  = var.project_id
}

# 2) CryptoKey con rotacion automatica cada 90 dias.
resource "google_kms_crypto_key" "bucket_key" {
  name            = "ck-bucket-data"
  key_ring        = google_kms_key_ring.data.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"   # 90 d

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true   # evitar que un apply destruya la clave y rompa el bucket.
  }
}

# 3) Binding IMPRESCINDIBLE: el service agent de GCS debe poder usar la clave.
#    Sin esto, el bucket falla al crearse. Es la causa #1 de tickets abiertos.
resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.bucket_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# 4) Bucket que referencia la clave. El default_kms_key_name es por bucket;
#    todos los objetos nuevos se encriptan con esa CryptoKey.
resource "google_storage_bucket" "data" {
  name                        = "demo-cmek-example-data"   # placeholder, no real
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true

  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}
```

## Qué observar

1. **El `depends_on` explícito** del bucket sobre el IAM member. Sin esta dependencia, Terraform puede intentar crear el bucket antes de que GCS pueda usar la clave y falla.
2. **`prevent_destroy` en la clave**. Borrar una CryptoKey mientras hay datos cifrados con ella es *destruir* esos datos. Un barrier accidental merece prevención.
3. **El `member` del service agent** es una dirección sintética derivada del project number. No existe físicamente hasta que GCS se ha usado al menos una vez en el project (lo garantiza enabling de la API).
4. **El bucket no re-cifra al rotar la CryptoKey.** Si pasas de rotación 90d a 30d, las versiones viejas siguen descifrando los objetos antiguos. Para re-cifrar un objeto concreto hay que hacer `gsutil rewrite -k gs://.../object` (reescritura explícita).

## Qué pasa si olvidas el binding

```
Error: googleapi: Error 400: The Cloud KMS key cannot be used to encrypt this
bucket because the service account service-000000000000@gs-project-accounts.iam.
gserviceaccount.com does not have the serviceusage.services.use permission.
```

Diagnóstico: añadir el binding `cryptoKeyEncrypterDecrypter` **sobre la CryptoKey** (no sobre el project entero) al service agent. Un `apply` repetido tras el fix lo arregla sin tocar nada más.

## Comparación con AWS

| GCP | AWS equivalente |
|---|---|
| CryptoKey con `rotation_period` | KMS CMK con `EnableKeyRotation` (anual, no configurable) |
| Service agent `service-...@gs-...` | S3 service-linked role / principal `s3.amazonaws.com` en key policy |
| `default_kms_key_name` en bucket | `SSE-KMS` + `bucket default encryption` |
| Keyring como contenedor | — (AWS no tiene equivalente; CMKs están sueltas en el account) |
