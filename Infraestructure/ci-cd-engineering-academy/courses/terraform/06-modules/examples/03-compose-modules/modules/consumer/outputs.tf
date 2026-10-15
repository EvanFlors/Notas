output "app_conf_path" {
  description = "Ruta efectiva del app.conf."
  value       = local_file.app_conf.filename
}
