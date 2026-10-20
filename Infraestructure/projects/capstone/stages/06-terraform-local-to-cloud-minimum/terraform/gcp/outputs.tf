output "network_name" {
  description = "VPC name consumed by stage 7."
  value       = google_compute_network.main.name
}

output "private_subnet_name" {
  description = "Private subnet for Cloud Run connector / future workloads."
  value       = google_compute_subnetwork.private.name
}

output "registry_url" {
  description = "Artifact Registry URL for `docker push`."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "state_bucket" {
  description = "GCS bucket backing the terraform remote state."
  value       = google_storage_bucket.state.name
}
