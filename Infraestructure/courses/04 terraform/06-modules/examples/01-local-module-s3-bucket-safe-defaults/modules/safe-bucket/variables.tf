variable "name" {
  type        = string
  description = "Nombre lógico del bucket (slug kebab-case, 3-30 chars). Se le añade un sufijo random."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.name))
    error_message = "name debe ser kebab-case (a-z, 0-9, '-'), 3-30 chars."
  }
}

variable "base_path" {
  type        = string
  description = "Directorio en el host donde se materializa el 'bucket'."
  default     = "/tmp/tf-06-ex01"
}

variable "versioning_enabled" {
  type        = bool
  description = "Habilita versioning (safe default: true)."
  default     = true
}

variable "encryption_enabled" {
  type        = bool
  description = "Habilita encryption (safe default: true)."
  default     = true
}

variable "access_log_enabled" {
  type        = bool
  description = "Habilita access log (safe default: true)."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags lógicos del bucket; se materializan en tags.json."
  default     = {}
}
