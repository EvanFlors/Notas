// Variables for capstone stage 07 — Azure Container Apps module.
// Defaults are placeholders. Never commit real subscription ids.

variable "location" {
  type        = string
  description = "Azure region (e.g. westeurope)."
  default     = "westeurope"
}

variable "project_tag" {
  type        = string
  description = "Tag applied to every resource for cleanup and cost tracking."
  default     = "capstone-07"
}

variable "image_digest" {
  type        = string
  description = "Pinned image reference BY DIGEST. Must match the digest cosign signed in stage 05."
  default     = "placeholderacr.azurecr.io/capstone-api@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "db_username" {
  type    = string
  default = "appuser"
}
