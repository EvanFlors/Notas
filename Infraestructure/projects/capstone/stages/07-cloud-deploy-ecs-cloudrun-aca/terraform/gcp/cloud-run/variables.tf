// Variables for capstone stage 07 — GCP Cloud Run v2 module.
// Defaults are placeholders. Never commit real project ids.

variable "project_id" {
  type        = string
  description = "GCP project id. Override via -var or TF_VAR_project_id."
  default     = "placeholder-project-id"
}

variable "region" {
  type        = string
  description = "GCP region (e.g. europe-west1)."
  default     = "europe-west1"
}

variable "project_tag" {
  type        = string
  description = "Label applied for cleanup and cost tracking."
  default     = "capstone-07"
}

variable "image_digest" {
  type        = string
  description = "Pinned image reference BY DIGEST. Must match the digest cosign signed in stage 05."
  default     = "europe-west1-docker.pkg.dev/placeholder-project-id/images/capstone-api@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "db_username" {
  type    = string
  default = "appuser"
}
