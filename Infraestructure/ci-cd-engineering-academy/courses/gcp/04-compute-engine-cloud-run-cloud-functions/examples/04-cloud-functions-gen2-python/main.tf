// Example — Cloud Functions gen 2 (HTTP). Local-only.
terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "placeholder-project-id"
  region  = "europe-west1"
}

resource "google_cloudfunctions2_function" "hello" {
  name     = "hello-http"
  location = "europe-west1"

  build_config {
    runtime     = "python312"
    entry_point = "handler"
    source {
      storage_source {
        bucket = "placeholder-source-bucket"
        object = "hello-http-src.zip"
      }
    }
  }

  service_config {
    service_account_email = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"
    min_instance_count    = 0
    max_instance_count    = 10
    available_memory      = "256M"
    timeout_seconds       = 30
  }
}
