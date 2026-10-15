terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# Starter: este recurso se llama "old_name".
# Tu tarea: renombrarlo a "new_name" sin que terraform plan proponga destroy+create.
# Pista: moved {}.
resource "local_file" "old_name" {
  filename = "/tmp/tf-09-01/greeting.txt"
  content  = "hola desde tf-09-01\n"
}
