# STARTER — contiene errores intencionales. No borrar comentarios "FIX:".

# FIX: name_prefix NO es secreto. `sensitive = true` aquí da falsa sensación
# de protección y degrada la UX del CLI (sale como <sensitive>). Debe quedar
# sin `sensitive`.
output "name_prefix" {
  value       = random_pet.app.id
  description = "Nombre lógico del stack."
  sensitive   = true
}

# FIX: esto FUGA la private key del CA en el output plain. Debe marcarse
# `sensitive = true`. Nota conceptual (NOTAS): sensitive oculta en CLI pero
# el valor sigue en el state en claro — por eso la clave real nunca debería
# vivir dentro de un recurso de TF para producción, sino en un KMS/HSM.
output "ca_private_key_pem" {
  value       = tls_private_key.ca.private_key_pem
  description = "Clave privada del CA auto-firmado (ejercicio didáctico)."
}

# OK.
output "ca_cert_pem" {
  value       = tls_self_signed_cert.ca.cert_pem
  description = "Certificado del CA auto-firmado."
}
