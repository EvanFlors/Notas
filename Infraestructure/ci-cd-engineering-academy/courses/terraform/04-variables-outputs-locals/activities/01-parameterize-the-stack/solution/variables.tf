variable "environment" {
  type        = string
  description = "Nombre lógico del ambiente (dev, stg, prod)."

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, stg, prod."
  }
}

variable "project" {
  type        = string
  description = "Nombre del proyecto en snake_case (3-30 chars, inicia con letra)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,29}$", var.project))
    error_message = "project debe ser snake_case, 3-30 chars, iniciar con letra."
  }
}

variable "key_count" {
  type        = number
  default     = 1
  description = "Cantidad de llaves TLS a generar."

  validation {
    condition     = var.key_count >= 1 && var.key_count <= 5
    error_message = "key_count debe estar entre 1 y 5."
  }
}

variable "rsa_bits" {
  type        = number
  default     = 2048
  description = "Tamaño en bits de la llave RSA (2048, 3072 o 4096)."

  validation {
    condition     = contains([2048, 3072, 4096], var.rsa_bits)
    error_message = "rsa_bits debe ser uno de: 2048, 3072, 4096."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags adicionales que se mergean sobre los base_tags."
}
