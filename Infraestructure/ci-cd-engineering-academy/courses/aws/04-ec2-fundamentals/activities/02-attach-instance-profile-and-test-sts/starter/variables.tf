variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name_prefix" {
  type    = string
  default = "aws04-sts"
}

variable "parameter_prefix" {
  description = "Prefijo del Parameter Store que la EC2 podra leer."
  type        = string
  default     = "/aws-04/demo"
}

variable "account_id_dummy" {
  description = "Account id ficticio para construir ARNs sin consultar AWS real."
  type        = string
  default     = "123456789012"
}
