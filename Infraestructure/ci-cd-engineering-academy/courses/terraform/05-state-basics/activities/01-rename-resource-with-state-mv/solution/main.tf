# Solution — tf-05-01-rename-resource-with-state-mv.
#
# The resource was renamed from "old_name" to "new_name" in BOTH the resource
# address AND the reference inside local_file.greeting_file.
#
# To avoid destroy+create, the student also ran:
#   terraform state mv random_pet.old_name random_pet.new_name

resource "random_pet" "new_name" {
  length    = 2
  separator = "-"
}

resource "local_file" "greeting_file" {
  filename        = "${path.module}/greeting.txt"
  content         = "hola ${random_pet.new_name.id}\n"
  file_permission = "0644"
}
