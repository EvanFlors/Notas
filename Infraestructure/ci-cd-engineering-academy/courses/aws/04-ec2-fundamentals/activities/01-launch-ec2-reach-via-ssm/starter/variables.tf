variable "region" {
  description = "AWS region. No se aplica realmente; sirve para que el provider configure endpoints."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "VPC id donde vive el SG. Dummy en modo lab (p. ej. vpc-00000000)."
  type        = string
  default     = "vpc-00000000"
}

variable "private_subnet_id" {
  description = "Subnet privada donde se lanza la EC2. Dummy en modo lab (p. ej. subnet-00000000)."
  type        = string
  default     = "subnet-00000000"
}

variable "name_prefix" {
  description = "Prefijo para los nombres de recursos."
  type        = string
  default     = "aws04-ssm"
}
