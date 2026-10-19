terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# NOTE: placeholder project id. Never apply this file against a real GCP
# project without replacing it. The module is designed for `terraform init
# -backend=false` + `terraform validate` only.
provider "google" {
  project = "example-project-id"
  region  = "europe-west1"
}

resource "google_service_account" "app_sa" {
  account_id   = "app-cloud-sql-client"
  display_name = "App service account for Cloud SQL (via Auth Proxy)"
}

resource "google_project_iam_member" "app_sa_cloudsql_client" {
  project = "example-project-id"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_sql_database_instance" "primary" {
  name                = "app-postgres-primary"
  database_version    = "POSTGRES_15"
  region              = "europe-west1"
  deletion_protection = true

  settings {
    tier              = "db-custom-1-3840"
    availability_type = "REGIONAL" # HA failover across zones

    ip_configuration {
      ipv4_enabled = false # <<< no public IP; access via Cloud SQL Auth Proxy
      # private_network would be set in a real deployment; omitted here.
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}

resource "google_sql_database" "appdb" {
  name     = "appdb"
  instance = google_sql_database_instance.primary.name
}

# IAM-authenticated user bound to the app service account; no Postgres
# password is stored anywhere.
resource "google_sql_user" "app_iam_user" {
  name     = google_service_account.app_sa.email
  instance = google_sql_database_instance.primary.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
