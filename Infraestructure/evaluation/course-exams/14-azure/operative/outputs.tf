output "resource_group_name" {
  value = azurerm_resource_group.exam.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.exam.vault_uri
}

output "workload_identity_client_id" {
  description = "Client ID of the user-assigned MI used by the workload. Not a secret, pero convencionalmente lo marcamos sensitive para no ensuciar logs."
  value       = azurerm_user_assigned_identity.uami_workload.client_id
}

# BUG intencional (OP-task-2): este output filtra el secret del SP.
# Elimina este bloque entero cuando sustituyas el SP por la MI.
output "workload_sp_secret" {
  value     = azuread_service_principal_password.workload_sp.value
  sensitive = false
}

# BUG intencional (OP-task-2): `principal_id` no es secreto pero convencionalmente
# se marca sensitive. Este output lo expone en texto plano.
output "workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.uami_workload.principal_id
}
