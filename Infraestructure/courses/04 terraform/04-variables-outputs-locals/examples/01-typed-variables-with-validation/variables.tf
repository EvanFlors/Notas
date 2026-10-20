variable "environment" {
  type        = string
  description = "Nombre lógico del ambiente (dev, stg, prod)."

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, stg, prod."
  }
}

variable "pet_length" {
  type        = number
  default     = 2
  description = "Cantidad de palabras en el nombre generado por random_pet."

  validation {
    condition     = var.pet_length >= 1 && var.pet_length <= 5
    error_message = "pet_length debe estar entre 1 y 5 (inclusive)."
  }
}

variable "service" {
  type = object({
    name = string
    team = string
    tags = optional(map(string), {})
  })
  description = "Metadata del servicio. 'tags' es opcional y se mergea con los tags base."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,19}$", var.service.name))
    error_message = "service.name debe ser snake_case (3-20 chars, iniciar con letra, solo [a-z0-9_])."
  }

  validation {
    condition     = length(var.service.team) > 0
    error_message = "service.team no puede estar vacío."
  }
}

variable "feature_flags" {
  type = object({
    enable_metrics = optional(bool, true)
    enable_tracing = optional(bool, false)
  })
  default     = {}
  description = "Flags booleanos del servicio. Todos opcionales con default razonable."
}
