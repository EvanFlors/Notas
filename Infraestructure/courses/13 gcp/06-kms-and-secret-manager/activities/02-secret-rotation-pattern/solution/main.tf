# Solucion de referencia — gcp-06-02-secret-rotation-pattern.
# Plan NO aplicado. Valores de secret son ficticios (fake-sk-...).

variable "project_id" {
  type    = string
  default = "demo-secret-example"
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

# Topic al que Secret Manager publica el evento de rotacion.
resource "google_pubsub_topic" "secret_rotation" {
  name    = "topic-secret-rotation"
  project = var.project_id
}

# Secret con rotacion configurada cada 30 dias y replicacion automatica.
resource "google_secret_manager_secret" "api_key" {
  secret_id = "external-api-key"
  project   = var.project_id

  replication {
    auto {}
  }

  rotation {
    rotation_period    = "2592000s"            # 30 d
    next_rotation_time = "2026-11-15T03:00:00Z"
    # El topic DEBE existir antes y el service agent de Secret Manager
    # debe tener roles/pubsub.publisher sobre el (binding separado).
  }

  topics {
    name = google_pubsub_topic.secret_rotation.id
  }
}

# Primera version. En un flujo real el valor se crea con `gcloud secrets
# versions add` desde el rotator — no por Terraform. Aqui va ficticio.
resource "google_secret_manager_secret_version" "api_key_v1" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "fake-sk-v1-REPLACE_IN_ROTATOR_NEVER_REAL"
}

# Principal consumidor: service account del servicio Cloud Run.
# Rol de LECTURA sobre el secret concreto (no sobre el project).
resource "google_secret_manager_secret_iam_member" "run_accessor" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:sa-run-app@${var.project_id}.iam.gserviceaccount.com"
}
