output "network_vpc_id" {
  description = "VPC id producido por module.network."
  value       = module.network.vpc_id
}

output "app_conf_path" {
  description = "Ruta del app.conf producido por module.consumer."
  value       = module.consumer.app_conf_path
}
