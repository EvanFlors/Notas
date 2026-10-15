output "vpc_id" {
  description = "ID lógico del VPC creado."
  value       = local.vpc_id
}

output "network_file" {
  description = "Ruta al network.json materializado."
  value       = local_file.network_json.filename
}
