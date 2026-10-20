output "service_url" {
  description = "Public HTTPS URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.api.uri
}

output "runtime_sa_email" {
  value = google_service_account.runtime.email
}

output "db_secret_id" {
  value = google_secret_manager_secret.db_dsn.secret_id
}
