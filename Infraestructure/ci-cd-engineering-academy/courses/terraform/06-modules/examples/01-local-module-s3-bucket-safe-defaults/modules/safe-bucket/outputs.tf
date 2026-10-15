output "bucket_name" {
  description = "Nombre efectivo del bucket (incluye el sufijo random)."
  value       = local.full_name
}

output "bucket_path" {
  description = "Ruta en el host donde vive el bucket (contrato de salida)."
  value       = local.bucket_path
}

output "versioning_enabled" {
  description = "Estado efectivo de versioning."
  value       = var.versioning_enabled
}

output "encryption_enabled" {
  description = "Estado efectivo de encryption."
  value       = var.encryption_enabled
}
