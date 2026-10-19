############################################################
# gcp-10-01 — Reference WIF Terraform.
#
# NOT APPLIED. All project IDs and account numbers are
# placeholders. Do NOT `terraform apply` this file against a
# real GCP project without reviewing every binding.
############################################################

variable "project_id" {
  type    = string
  default = "my-project-123"
}

variable "project_number" {
  type    = string
  default = "123456789012"
}

variable "github_repo" {
  type    = string
  default = "acme/checkout"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

# ---------- Workload Identity Pool ----------
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
  description               = "WIF pool for GitHub Actions pipelines (acme org)"
}

# ---------- OIDC Provider for GitHub ----------
resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  # Hard pin: only tokens coming from the acme/checkout repo
  # are accepted by this provider. A fork of the repo in a
  # different owner would fail here, BEFORE binding evaluation.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""
}

# ---------- Service Account impersonated by the pipeline ----------
resource "google_service_account" "gha_publisher" {
  project      = var.project_id
  account_id   = "gha-publisher"
  display_name = "GitHub Actions image publisher"
  description  = "Impersonated by the publish.yml workflow via WIF. No keys."
}

# ---------- Binding: only tokens from acme/checkout can impersonate ----------
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.gha_publisher.name
  role               = "roles/iam.workloadIdentityUser"
  member = format(
    "principalSet://iam.googleapis.com/projects/%s/locations/global/workloadIdentityPools/%s/attribute.repository/%s",
    var.project_number,
    google_iam_workload_identity_pool.github.workload_identity_pool_id,
    var.github_repo,
  )
}

# ---------- Minimal permission: writer on the specific Artifact Registry repo ----------
resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = var.project_id
  location   = var.region
  repository = "prod-images"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.gha_publisher.email}"
}
