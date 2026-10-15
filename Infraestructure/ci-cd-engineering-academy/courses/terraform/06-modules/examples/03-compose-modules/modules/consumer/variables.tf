variable "app_name" {
  type        = string
  description = "Nombre de la app consumidora."
}

variable "vpc_id" {
  type        = string
  description = "ID del VPC donde la app lee/escribe. Pasado por el root desde module.network."
}

variable "base_path" {
  type        = string
  description = "Dónde se materializa app.conf."
  default     = "/tmp/tf-06-ex03"
}
