// Example — Cloud Run canary 95/5 via two named revisions.
// Local-only. Do NOT apply.

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

  // The template describes the newest revision being deployed (v2).
  template {
    revision        = "capstone-api-v2"
    service_account = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"

    containers {
      image = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-api:v2"
      ports {
        container_port = 8080
      }
    }
  }

  // Split: 95% to the previous revision, 5% to v2 (canary).
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
