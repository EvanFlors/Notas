module "app" {
  source = "../../modules/app"

  environment          = "prod"
  project              = "shop"
  replica_count        = 3
  instance_class_label = "large"
}

output "app_name"      { value = module.app.name }
output "manifest_path" { value = module.app.manifest_path }
