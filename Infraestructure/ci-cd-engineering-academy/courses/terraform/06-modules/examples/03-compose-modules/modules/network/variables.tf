variable "name" {
  type        = string
  description = "Nombre lógico de la red."
}

variable "base_path" {
  type        = string
  description = "Dónde se materializa el network.json."
  default     = "/tmp/tf-06-ex03"
}
