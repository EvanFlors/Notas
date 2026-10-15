variable "users" {
  description = "Lista de usuarios. ANTI-PATRÓN: la lista implica identidad por posición."
  type        = list(string)
  default     = ["alice", "bob", "carol"]
}
