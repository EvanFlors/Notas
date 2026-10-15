terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# Starter: stack vacío.
# Tu tarea: adoptar el identificador producido por bootstrap.sh (id = "AAAAAA",
# un random_id de 4 bytes en base64url) usando un bloque import {} y un
# resource "random_id" "adopted" con byte_length = 4.
# Ver README.md -> Paso 2.
