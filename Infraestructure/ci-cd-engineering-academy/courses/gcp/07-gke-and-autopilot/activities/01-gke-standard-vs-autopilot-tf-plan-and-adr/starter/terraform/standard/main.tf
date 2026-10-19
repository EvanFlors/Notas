// Starter — GKE Standard cluster.
// Fill in TODOs. Keep project_id as a placeholder (never a real ID).
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

// TODO: declare the Standard cluster.
// Required blocks (the validator greps for them):
//   - resource "google_container_cluster" "primary"
//   - remove_default_node_pool = true
//   - initial_node_count       = 1
//   - workload_identity_config { workload_pool = "my-project-123.svc.id.goog" }
//   - release_channel { channel = "REGULAR" }   // or "STABLE" for prod
//   - private_cluster_config { enable_private_nodes = true, ... }
//   - network_policy { enabled = true, provider = "CALICO" }
//     OR datapath_provider = "ADVANCED_DATAPATH" (Dataplane V2)
//
// Then a separate node pool:
//   - resource "google_container_node_pool" "primary_nodes"
//   - node_config { machine_type, shielded_instance_config { ... }, ... }
//   - management { auto_upgrade = true, auto_repair = true }
