// Starter — capstone 07 activity 01 — GCP Cloud Run v2.
// Four TODO blocks must be solved to pass the validator.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "pg" {
  name             = "${var.project_tag}-pg"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
    }
  }

  deletion_protection = false
}

resource "google_sql_user" "app" {
  instance = google_sql_database_instance.pg.name
  name     = var.db_username
  password = random_password.db.result
}

// ---------------------------------------------------------------------------
// TODO 1 — Pin image BY DIGEST. The value passed to containers[].image
// must contain "@sha256:" literally. Use var.image_digest.
// ---------------------------------------------------------------------------
locals {
  // TODO 1: replace null with var.image_digest
  image_ref = null
}

// ---------------------------------------------------------------------------
// TODO 2 — Create a dedicated SERVICE ACCOUNT for the Cloud Run runtime.
// Resource type: google_service_account.
// account_id = "${var.project_tag}-rt".
// ---------------------------------------------------------------------------

// TODO 2 — declare resource "google_service_account" "runtime" HERE.

// ---------------------------------------------------------------------------
// TODO 3 — Create the DB DSN secret and grant the runtime SA
// roles/secretmanager.secretAccessor on it.
// Resources: google_secret_manager_secret, google_secret_manager_secret_version,
// google_secret_manager_secret_iam_member.
// DSN format: postgresql://user:pass@<private_ip>:5432/postgres.
// ---------------------------------------------------------------------------

// TODO 3 — declare the three resources HERE.

// ---------------------------------------------------------------------------
// TODO 4 — In the Cloud Run service, set template.service_account to the
// runtime SA email AND inject APP_DB_DSN using env.value_source.secret_key_ref
// pointing to the secret you created in TODO 3 (NOT env.value with the DSN).
// ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "api" {
  name     = "${var.project_tag}-api"
  location = var.region

  template {
    // TODO 4: service_account = google_service_account.runtime.email
    service_account = null

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = local.image_ref

      ports { container_port = 8080 }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      // TODO 4: add an env{} block with name = "APP_DB_DSN" and
      // value_source.secret_key_ref referencing the secret.

      env {
        name  = "PORT"
        value = "8080"
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    capstone = "07"
    project  = var.project_tag
  }
}
