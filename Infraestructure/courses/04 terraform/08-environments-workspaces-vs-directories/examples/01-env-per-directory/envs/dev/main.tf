module "app" {
  source = "../../modules/app"

  environment          = "dev"
  project              = "shop"
  replica_count        = 1
  instance_class_label = "small"
}

output "app_name" {
  value = module.app.name
}

output "manifest_path" {
  value = module.app.manifest_path
}
