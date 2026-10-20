// Starter — GKE Autopilot cluster.
// Fill in TODOs. Keep project_id as a placeholder.
// Validate with: terraform init -backend=false && terraform validate

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "my-project-123" // placeholder — never a real ID
  region  = "europe-west1"
}

// TODO: declare the Autopilot cluster.
// Required blocks (the validator greps for them):
//   - resource "google_container_cluster" "autopilot"
//   - enable_autopilot = true
//   - workload_identity_config { workload_pool = "my-project-123.svc.id.goog" }
//   - release_channel { channel = "REGULAR" }  // or "STABLE" for prod
//   - private_cluster_config { enable_private_nodes = true, ... }
//
// IMPORTANT: do NOT declare google_container_node_pool for Autopilot.
// Google manages nodes. Declaring a node pool is a Terraform error.
