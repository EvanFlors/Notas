output "app_fqdn" {
  description = "Public FQDN of the Container App ingress."
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "identity_client_id" {
  value = azurerm_user_assigned_identity.runtime.client_id
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}
