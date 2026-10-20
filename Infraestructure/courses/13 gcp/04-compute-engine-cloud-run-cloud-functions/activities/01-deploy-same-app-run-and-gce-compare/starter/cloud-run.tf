// Starter — Cloud Run v2 service for the capstone API.
// Fill in TODOs. Do NOT apply to a real GCP project.

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

// TODO 1: declare the Cloud Run v2 service.
//   - name = "capstone-api"
//   - location = "europe-west1"
//   - template.service_account = var.runtime_sa_email  (NOT the default)
//   - template.containers:
//       image = var.image_uri
//       ports.container_port = 8080
//       env { name = "PORT"  value = "8080" }
//   - traffic: percent = 100 (LATEST allocation).
