# Starter stack for tf-05-01-rename-resource-with-state-mv.
#
# Your task:
#   1. terraform init && terraform apply
#   2. Rename "old_name" -> "new_name" in THIS file.
#   3. Use `terraform state mv` so that `terraform plan` is a no-op.
#
# Do NOT touch versions.tf.

resource "random_pet" "old_name" {
  length    = 2
  separator = "-"
}

resource "local_file" "greeting_file" {
  filename        = "${path.module}/greeting.txt"
  content         = "hola ${random_pet.old_name.id}\n"
  file_permission = "0644"
}
