output "cluster_name" {
  value       = google_container_cluster.this.name
  description = "Nombre del cluster GKE."
}

output "cluster_endpoint" {
  value       = google_container_cluster.this.endpoint
  description = "Endpoint del apiserver."
  sensitive   = true
}

output "kubeconfig_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${var.region} --project ${var.project_id}"
  description = "Comando sugerido para poblar ~/.kube/config."
}
