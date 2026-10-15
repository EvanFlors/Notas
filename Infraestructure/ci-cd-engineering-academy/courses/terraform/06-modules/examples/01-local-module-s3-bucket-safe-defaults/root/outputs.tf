output "logs_bucket_path" {
  description = "Ruta efectiva del bucket de logs."
  value       = module.logs_bucket.bucket_path
}

output "artifacts_bucket_path" {
  description = "Ruta efectiva del bucket de artifacts."
  value       = module.artifacts_bucket.bucket_path
}

output "all_bucket_names" {
  description = "Lista de nombres efectivos de todos los buckets."
  value = [
    module.logs_bucket.bucket_name,
    module.artifacts_bucket.bucket_name,
  ]
}
