terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# Content canónico de la config. Marca el "estado deseado".
resource "local_file" "note" {
  filename = "${path.module}/note.txt"
  content  = "contenido canonico gestionado por terraform\n"
}
