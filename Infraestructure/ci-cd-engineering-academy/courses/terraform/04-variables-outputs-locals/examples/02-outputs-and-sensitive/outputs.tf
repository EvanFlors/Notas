output "public_pem" {
  value       = tls_private_key.demo.public_key_pem
  description = "Llave pública (seguro mostrar)."
}

output "private_pem" {
  value       = tls_private_key.demo.private_key_pem
  description = "Llave privada en PEM. Marcada sensitive — pero sigue en claro en el state."
  sensitive   = true
}

output "kid_dummy_token" {
  value       = random_pet.dummy_key_id.id
  description = "Identificador dummy; marcado sensitive para demostrar la propagación."
  sensitive   = true
}

# Este output usa un valor sensitive dentro de una expresión; TF lo marca
# sensitive automáticamente. No necesitas repetir `sensitive = true`.
output "derived_fingerprint" {
  value       = sha256(tls_private_key.demo.private_key_pem)
  description = "Fingerprint derivado del PEM privado — hereda la marca sensitive."
  sensitive   = true
}
