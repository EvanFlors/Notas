# Solucion de referencia — gcp-06-01-cmek-rotation-impact.
# Esta configuracion NO se aplica contra GCP. Es un plan documentado.

variable "project_id" {
  type    = string
  default = "demo-cmek-example"
}

variable "project_number" {
  type    = string
  default = "000000000000"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1) Keyring regional. Historico: no se puede destruir.
resource "google_kms_key_ring" "data" {
  name     = "kr-data"
  location = var.region
  project  = var.project_id
}

# 2) CryptoKey con rotation period de 90 dias.
resource "google_kms_crypto_key" "bucket_key" {
  name            = "ck-bucket-data"
  key_ring        = google_kms_key_ring.data.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# 3) IAM binding imprescindible: service agent de GCS puede usar la clave.
resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.bucket_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# 4) Bucket que referencia la CryptoKey como default encryption.
resource "google_storage_bucket" "data" {
  name                        = "${var.project_id}-data"
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = false

  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}
