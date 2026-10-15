output "name_prefix" {
  value       = local.name_prefix
  description = "Prefijo canónico <project>-<environment> derivado en locals."
}

output "manifest_path" {
  value       = local_file.manifest.filename
  description = "Ruta en disco del manifest generado por el stack."
}

output "key_fingerprints" {
  value       = [for k in tls_private_key.keys : sha256(k.public_key_pem)]
  description = "Lista de SHA256 de la llave pública de cada tls_private_key."
}

output "effective_tags" {
  value       = local.effective_tags
  description = "Tags base del stack mergeados con los tags que vengan por variable."
}
