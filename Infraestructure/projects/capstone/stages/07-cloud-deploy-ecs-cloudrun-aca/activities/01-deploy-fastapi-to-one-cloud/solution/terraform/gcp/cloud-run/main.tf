// Capstone stage 07 — Cloud Run v2 + Cloud SQL Postgres + Secret Manager.
// Pins image by digest. CI runs plan only; apply is manual.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

// Dedicated runtime service account for Cloud Run.
resource "google_service_account" "runtime" {
  account_id   = "${var.project_tag}-rt"
  display_name = "Cloud Run runtime SA for ${var.project_tag}"
}

// ---------------------------------------------------------------------------
// Cloud SQL Postgres with PRIVATE IP only.
// ---------------------------------------------------------------------------
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
    disk_size         = 10
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
    }

    backup_configuration {
      enabled = true
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
// Secret Manager: DSN as a single secret.
// ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_dsn" {
  secret_id = "${var.project_tag}-db-dsn"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_dsn" {
  secret      = google_secret_manager_secret.db_dsn.id
  secret_data = "postgresql://${var.db_username}:${random_password.db.result}@${google_sql_database_instance.pg.private_ip_address}:5432/postgres"
}

// Grant the runtime SA read access to the secret.
resource "google_secret_manager_secret_iam_member" "runtime_access" {
  secret_id = google_secret_manager_secret.db_dsn.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

// ---------------------------------------------------------------------------
// Cloud Run v2 service.
// ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "api" {
  name     = "${var.project_tag}-api"
  location = var.region

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = var.image_digest

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name = "APP_DB_DSN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_dsn.secret_id
            version = "latest"
          }
        }
      }

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

  depends_on = [google_secret_manager_secret_iam_member.runtime_access]
}
