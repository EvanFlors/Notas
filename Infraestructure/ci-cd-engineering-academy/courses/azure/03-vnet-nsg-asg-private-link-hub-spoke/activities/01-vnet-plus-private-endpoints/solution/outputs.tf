output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "ID de la VNet principal (consumido por peerings futuros)"
}

output "subnet_app_id" {
  value       = azurerm_subnet.app.id
  description = "ID de la subnet de aplicacion"
}

output "subnet_pe_id" {
  value       = azurerm_subnet.pe.id
  description = "ID de la subnet dedicada a Private Endpoints"
}

output "private_endpoint_storage_ip" {
  value       = azurerm_private_endpoint.storage_blob.private_service_connection[0].private_ip_address
  description = "IP privada asignada al PE de Blob Storage (dentro de snet-pe)"
}

output "private_endpoint_kv_ip" {
  value       = azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address
  description = "IP privada asignada al PE de Key Vault"
}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Nombre global del Storage Account (sufijo random)"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Nombre global del Key Vault (sufijo random)"
}
