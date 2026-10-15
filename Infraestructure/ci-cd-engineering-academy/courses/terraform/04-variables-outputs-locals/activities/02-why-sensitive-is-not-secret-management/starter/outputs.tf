output "public_key" {
  value       = tls_private_key.demo.public_key_pem
  description = "Llave pública en PEM — seguro mostrar."
}

output "dummy_token" {
  value       = random_pet.dummy_token.id
  description = "Token dummy. Marcado sensitive — pero sigue en claro en el state."
  sensitive   = true
}

output "derived_fingerprint" {
  value       = sha256(tls_private_key.demo.private_key_pem)
  description = "Fingerprint derivado del PEM privado — hereda la marca sensitive."
  sensitive   = true
}
