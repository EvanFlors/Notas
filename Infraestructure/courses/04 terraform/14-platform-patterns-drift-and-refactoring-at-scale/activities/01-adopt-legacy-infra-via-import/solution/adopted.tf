resource "local_file" "app_alpha" {
  filename        = "/tmp/tf14-act01-legacy/app-alpha.conf"
  file_permission = "0644"
  content         = <<-EOT
    app=alpha
    tier=web
    port=9091
  EOT
}

resource "local_file" "app_beta" {
  filename        = "/tmp/tf14-act01-legacy/app-beta.conf"
  file_permission = "0644"
  content         = <<-EOT
    app=beta
    tier=api
    port=9092
  EOT
}

resource "local_file" "app_gamma" {
  filename        = "/tmp/tf14-act01-legacy/app-gamma.conf"
  file_permission = "0644"
  content         = <<-EOT
    app=gamma
    tier=worker
    port=9093
  EOT
}
