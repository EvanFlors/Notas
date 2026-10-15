resource "random_pet" "codename" {
  length    = 3
  separator = "-"
}

resource "local_file" "badge" {
  filename        = "/tmp/tf-02-02-out/${random_pet.codename.id}.txt"
  content         = "soy ${random_pet.codename.id}\n"
  file_permission = "0644"
}

output "badge_path" {
  value = local_file.badge.filename
}

output "codename" {
  value = random_pet.codename.id
}
