provider "google" {
  project = var.project_id
  region  = var.region
}

############################################
# 1. Backend infra (GCS bucket for state)
#    Locking in GCS is native since provider 4.x — no extra table needed.
############################################

resource "google_storage_bucket" "state" {
  name                        = "${var.project}-tfstate-${var.project_id}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

############################################
# 2. Network (custom VPC + private subnet + Cloud NAT)
############################################

resource "google_compute_network" "main" {
  name                    = "${var.project}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.project}-private"
  ip_cidr_range            = var.vpc_cidr_primary
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.project}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "deny_ingress" {
  name    = "${var.project}-deny-ingress"
  network = google_compute_network.main.name

  # Explicit deny-all ingress to make the baseline posture obvious. GCP already
  # denies by default; this makes the intent audit-friendly.
  deny {
    protocol = "all"
  }

  direction = "INGRESS"
  priority  = 65534
  source_ranges = ["0.0.0.0/0"]
}

############################################
# 3. Container registry (Artifact Registry, Docker format)
############################################

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${var.project}-app"
  description   = "Capstone app container images"
  format        = "DOCKER"
  labels        = var.labels
}

############################################
# 4. Workload Identity Federation for GitHub Actions
#    Declared but commented out — stage 7 enables it. Keeping the block
#    here lets code review happen in this stage.
############################################

# resource "google_iam_workload_identity_pool" "github" {
#   workload_identity_pool_id = "${var.project}-gh-pool"
#   display_name              = "GitHub Actions pool"
# }
#
# resource "google_iam_workload_identity_pool_provider" "github" {
#   workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
#   workload_identity_pool_provider_id = "${var.project}-gh-provider"
#
#   attribute_mapping = {
#     "google.subject"       = "assertion.sub"
#     "attribute.repository" = "assertion.repository"
#   }
#
#   attribute_condition = "assertion.repository == \"${var.github_org}/${var.github_repo}\""
#
#   oidc {
#     issuer_uri = "https://token.actions.githubusercontent.com"
#   }
# }
