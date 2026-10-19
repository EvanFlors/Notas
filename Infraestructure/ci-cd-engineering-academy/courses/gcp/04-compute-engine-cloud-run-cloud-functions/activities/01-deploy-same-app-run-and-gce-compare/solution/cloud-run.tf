// Reference solution — Cloud Run v2 service.
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

variable "image_uri" {
  type    = string
  default = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-api:v1"
}

variable "runtime_sa_email" {
  type    = string
  default = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service" "api" {
  name     = "capstone-api"
  location = "europe-west1"

  template {
    service_account = var.runtime_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    containers {
      image = var.image_uri
      ports {
        container_port = 8080
      }
      env {
        name  = "PORT"
        value = "8080"
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}
