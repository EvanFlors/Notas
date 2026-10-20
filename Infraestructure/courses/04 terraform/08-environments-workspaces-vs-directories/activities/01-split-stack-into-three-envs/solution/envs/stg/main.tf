module "app" {
  source = "../../modules/app"

  environment          = "stg"
  project              = "shop"
  replica_count        = 2
  instance_class_label = "medium"
}

output "app_name"      { value = module.app.name }
output "manifest_path" { value = module.app.manifest_path }
