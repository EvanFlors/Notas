locals {
  # On the "default" workspace we treat the stack as "dev" so the demo is still
  # useful without creating a workspace. For any other workspace, that workspace
  # IS the ephemeral environment name.
  env_suffix = terraform.workspace == "default" ? "dev" : terraform.workspace

  # A tag that makes it obvious this is a short-lived env.
  is_ephemeral = terraform.workspace != "default"
}

resource "random_pet" "name" {
  prefix    = "${var.project}-${local.env_suffix}"
  separator = "-"
  length    = 2
  keepers = {
    project   = var.project
    workspace = terraform.workspace
  }
}

resource "local_file" "manifest" {
  filename = "out/manifest.json"
  content = jsonencode({
    project      = var.project
    workspace    = terraform.workspace
    env_suffix   = local.env_suffix
    is_ephemeral = local.is_ephemeral
    name         = random_pet.name.id
    tags = {
      project      = var.project
      env          = local.env_suffix
      workspace    = terraform.workspace
      is_ephemeral = tostring(local.is_ephemeral)
      managed_by   = "terraform"
    }
  })
  file_permission = "0644"
}

output "name"      { value = random_pet.name.id }
output "workspace" { value = terraform.workspace }
