// Example — Cloud Run jobs. Local-only; do NOT apply.
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

resource "google_cloud_run_v2_job" "nightly" {
  name     = "capstone-nightly-batch"
  location = "europe-west1"

  template {
    template {
      service_account = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"
      max_retries     = 1
      timeout         = "600s"
      containers {
        image = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-batch:v1"
        env {
          name  = "BATCH_SIZE"
          value = "500"
        }
      }
    }
  }
}
