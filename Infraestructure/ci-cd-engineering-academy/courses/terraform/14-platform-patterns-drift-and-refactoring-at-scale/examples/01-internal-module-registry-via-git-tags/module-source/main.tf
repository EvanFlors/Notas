locals {
  # Platform-enforced naming: greeting-<name>.txt. Not negotiable.
  filename = "${var.output_dir}/greeting-${var.name}.txt"

  # Platform-enforced metadata header prepended to every file.
  header = "# owner=${var.owner}\n# managed-by=tf-14-golden-greeter\n"
}

resource "local_file" "greeting" {
  filename        = local.filename
  content         = "${local.header}${var.message}\n"
  file_permission = "0644"
}
