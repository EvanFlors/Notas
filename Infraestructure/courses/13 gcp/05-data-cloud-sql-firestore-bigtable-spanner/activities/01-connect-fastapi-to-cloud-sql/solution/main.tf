terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# Placeholder project id. NEVER apply against a real project without
# replacing it. This module validates only (`terraform init -backend=false`
# + `terraform validate`); it is not meant for `apply`.
provider "google" {
  project = "example-project-id"
  region  = "europe-west1"
}

resource "google_service_account" "app_sa" {
  account_id   = "checkout-cloud-sql-client"
  display_name = "checkout API Cloud SQL client (via Auth Proxy)"
}

resource "google_project_iam_member" "app_sa_cloudsql_client" {
  project = "example-project-id"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_sql_database_instance" "primary" {
  name                = "checkout-postgres-primary"
  database_version    = "POSTGRES_15"
  region              = "europe-west1"
  deletion_protection = true

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "REGIONAL" # multi-zone HA

    ip_configuration {
      ipv4_enabled = false # no public IP; access only via Cloud SQL Auth Proxy
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "02:00"
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    insights_config {
      query_insights_enabled = true
    }
  }
}

resource "google_sql_database" "appdb" {
  name     = "appdb"
  instance = google_sql_database_instance.primary.name
}

resource "google_sql_user" "app_iam_user" {
  name     = google_service_account.app_sa.email
  instance = google_sql_database_instance.primary.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
