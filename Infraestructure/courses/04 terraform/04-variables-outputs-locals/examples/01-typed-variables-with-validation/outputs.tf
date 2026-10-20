output "pet_name" {
  value       = random_pet.name.id
  description = "Nombre canónico generado para este ambiente."
}

output "manifest_path" {
  value       = local_file.manifest.filename
  description = "Ruta en disco del manifest generado."
}

output "effective_tags" {
  value       = local.effective_tags
  description = "Mapa de tags efectivos tras aplicar los defaults."
}
