// Reference solution — Cloud Run canary 95/5 via two named revisions.
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

resource "google_cloud_run_v2_service" "api" {
  name     = "capstone-api"
  location = "europe-west1"

  template {
    revision        = "capstone-api-v2"
    service_account = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"

    containers {
      image = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-api:v2"
      ports {
        container_port = 8080
      }
      env {
        name  = "PORT"
        value = "8080"
      }
    }
  }

  traffic {
    type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
    revision = "capstone-api-v1"
    percent  = 95
  }

  traffic {
    type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
    revision = "capstone-api-v2"
    percent  = 5
  }
}
