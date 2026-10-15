output "name" {
  description = "Fully-qualified name of the app for this environment."
  value       = random_pet.name.id
}

output "manifest_path" {
  description = "Where the rendered manifest was written."
  value       = local_file.manifest.filename
}

output "manifest" {
  description = "Full manifest (handy for cross-module composition in later labs)."
  value       = jsondecode(local_file.manifest.content)
}
