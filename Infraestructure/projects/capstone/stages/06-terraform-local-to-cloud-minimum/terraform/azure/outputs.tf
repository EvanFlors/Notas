output "resource_group" {
  description = "Resource group hosting all stack resources."
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "VNet name consumed by stage 7."
  value       = azurerm_virtual_network.main.name
}

output "app_subnet_id" {
  description = "Subnet id for the app runtime (Container Apps / AKS)."
  value       = azurerm_subnet.app.id
}

output "registry_url" {
  description = "ACR login server for `docker push`."
  value       = azurerm_container_registry.app.login_server
}

output "state_storage_account" {
  description = "Storage account backing the terraform remote state."
  value       = azurerm_storage_account.state.name
}

output "state_container" {
  description = "Blob container backing the terraform remote state."
  value       = azurerm_storage_container.state.name
}
