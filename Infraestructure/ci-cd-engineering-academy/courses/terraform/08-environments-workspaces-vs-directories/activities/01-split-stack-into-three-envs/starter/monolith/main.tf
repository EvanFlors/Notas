# ANTI-PATTERN ON PURPOSE.
# Three environments crammed into one root module, one state, three near-copies
# of the same resources with the parameters inlined. Fix me by splitting into
# envs/{dev,stg,prod}/ + a shared module in modules/app/.

locals {
  project = "shop"
}

# -------- dev --------

resource "random_pet" "dev" {
  prefix    = "${local.project}-dev"
  separator = "-"
  length    = 2
  keepers = {
    project = local.project
    env     = "dev"
  }
}

resource "random_id" "dev_deploy_token" {
  byte_length = 4
  keepers = {
    replicas = "1"
    class    = "small"
  }
}

resource "local_file" "dev_manifest" {
  filename        = "out/dev-manifest.json"
  file_permission = "0644"
  content = jsonencode({
    project  = local.project
    env      = "dev"
    name     = random_pet.dev.id
    replicas = 1
    class    = "small"
    token    = random_id.dev_deploy_token.hex
    tags = {
      project    = local.project
      env        = "dev"
      managed_by = "terraform"
    }
  })
}

# -------- stg --------

resource "random_pet" "stg" {
  prefix    = "${local.project}-stg"
  separator = "-"
  length    = 2
  keepers = {
    project = local.project
    env     = "stg"
  }
}

resource "random_id" "stg_deploy_token" {
  byte_length = 4
  keepers = {
    replicas = "2"
    class    = "medium"
  }
}

resource "local_file" "stg_manifest" {
  filename        = "out/stg-manifest.json"
  file_permission = "0644"
  content = jsonencode({
    project  = local.project
    env      = "stg"
    name     = random_pet.stg.id
    replicas = 2
    class    = "medium"
    token    = random_id.stg_deploy_token.hex
    tags = {
      project    = local.project
      env        = "stg"
      managed_by = "terraform"
    }
  })
}

# -------- prod --------

resource "random_pet" "prod" {
  prefix    = "${local.project}-prod"
  separator = "-"
  length    = 2
  keepers = {
    project = local.project
    env     = "prod"
  }
}

resource "random_id" "prod_deploy_token" {
  byte_length = 4
  keepers = {
    replicas = "3"
    class    = "large"
  }
}

resource "local_file" "prod_manifest" {
  filename        = "out/prod-manifest.json"
  file_permission = "0644"
  content = jsonencode({
    project  = local.project
    env      = "prod"
    name     = random_pet.prod.id
    replicas = 3
    class    = "large"
    token    = random_id.prod_deploy_token.hex
    tags = {
      project    = local.project
      env        = "prod"
      managed_by = "terraform"
    }
  })
}

output "dev_name"  { value = random_pet.dev.id }
output "stg_name"  { value = random_pet.stg.id }
output "prod_name" { value = random_pet.prod.id }
