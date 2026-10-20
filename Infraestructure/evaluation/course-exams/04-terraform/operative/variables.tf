# STARTER — contiene errores intencionales. No borrar comentarios "FIX:".

# FIX: falta tipo explícito y validation (dev/stg/prod).
variable "environment" {
  default = "dev"
}

# OK — queda como está.
variable "name_prefix" {
  type        = string
  description = "Prefijo lógico para nombrar recursos (no es secreto)."
  default     = "exam"
}

# FIX: debe ser map(object({ role = string, email = string })).
# El tipo actual rompe `terraform validate` cuando se intenta usar for_each.
variable "users" {
  type = list(string)
  default = [
    "alice",
    "bob",
    "carol",
  ]
}

# OK — se usa como entrada al dynamic block.
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    description = string
  }))
  default = [
    { port = 80, protocol = "tcp", description = "http" },
    { port = 443, protocol = "tcp", description = "https" },
  ]
}
