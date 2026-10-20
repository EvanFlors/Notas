// Starter — Cloud Run canary 95/5. Fill in TODOs. Do NOT apply.

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

// TODO 1: declare google_cloud_run_v2_service "api" with:
//   - name = "capstone-api", location = "europe-west1"
//   - template.revision = "capstone-api-v2"
//   - template.service_account = "runtime-sa@placeholder-project-id.iam.gserviceaccount.com"
//   - template.containers.image = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-api:v2"
//   - template.containers.ports.container_port = 8080
//   - two traffic blocks:
//       { type=TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION  revision="capstone-api-v1"  percent=95 }
//       { type=TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION  revision="capstone-api-v2"  percent=5 }
