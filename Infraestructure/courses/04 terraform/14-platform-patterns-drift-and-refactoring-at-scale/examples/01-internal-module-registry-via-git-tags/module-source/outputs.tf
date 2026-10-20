output "path" {
  description = "Absolute path of the greeting file."
  value       = local_file.greeting.filename
}

output "owner" {
  description = "Owner tag echoed back (for consumer visibility)."
  value       = var.owner
}
