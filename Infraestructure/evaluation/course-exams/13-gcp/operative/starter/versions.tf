terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.40"
    }
  }
}

# NOTE: provider blocks are intentionally not configured with credentials.
# This exam is plan-only. Do NOT run `terraform apply`.
provider "google" {
  project = var.project_prod
  region  = var.region
}

provider "google-beta" {
  project = var.project_prod
  region  = var.region
}
