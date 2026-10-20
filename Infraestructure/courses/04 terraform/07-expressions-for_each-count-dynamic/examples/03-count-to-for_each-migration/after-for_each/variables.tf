variable "users" {
  description = "Lista de usuarios. Se convierte a set para alimentar for_each con claves estables."
  type        = list(string)
  default     = ["alice", "bob", "carol"]
}
