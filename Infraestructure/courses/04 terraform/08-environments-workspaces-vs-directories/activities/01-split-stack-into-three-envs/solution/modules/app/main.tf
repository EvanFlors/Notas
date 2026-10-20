terraform {
  required_version = ">= 1.3.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}

# Deterministic-ish naming: the pet name is stable per (project, environment)
# because the keepers only change when those inputs change.
resource "random_pet" "name" {
  prefix    = "${var.project}-${var.environment}"
  separator = "-"
  length    = 2
  keepers = {
    project = var.project
    env     = var.environment
  }
}

# A "deploy token" that only rotates when replica_count or instance class change.
resource "random_id" "deploy_token" {
  byte_length = 4
  keepers = {
    replicas = var.replica_count
    class    = var.instance_class_label
  }
}

locals {
  manifest = {
    project   = var.project
    env       = var.environment
    name      = random_pet.name.id
    replicas  = var.replica_count
    class     = var.instance_class_label
    token     = random_id.deploy_token.hex
    tags = {
      project    = var.project
      env        = var.environment
      managed_by = "terraform"
    }
  }
}

resource "local_file" "manifest" {
  filename        = "${var.out_dir}/manifest.json"
  content         = jsonencode(local.manifest)
  file_permission = "0644"
}
