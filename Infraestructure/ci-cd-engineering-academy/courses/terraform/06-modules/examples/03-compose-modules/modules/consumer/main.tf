resource "local_file" "app_conf" {
  filename = "${var.base_path}/apps/${var.app_name}/app.conf"
  content  = <<-EOT
    app_name=${var.app_name}
    vpc_id=${var.vpc_id}
  EOT
}
