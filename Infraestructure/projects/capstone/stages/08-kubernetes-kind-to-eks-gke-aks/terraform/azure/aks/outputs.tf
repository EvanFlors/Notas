output "cluster_name" {
  value       = azurerm_kubernetes_cluster.this.name
  description = "Nombre del cluster AKS."
}

output "cluster_fqdn" {
  value       = azurerm_kubernetes_cluster.this.fqdn
  description = "FQDN del apiserver."
}

output "kubeconfig_command" {
  value       = "az aks get-credentials --name ${azurerm_kubernetes_cluster.this.name} --resource-group ${azurerm_resource_group.this.name}"
  description = "Comando sugerido para poblar ~/.kube/config."
}
