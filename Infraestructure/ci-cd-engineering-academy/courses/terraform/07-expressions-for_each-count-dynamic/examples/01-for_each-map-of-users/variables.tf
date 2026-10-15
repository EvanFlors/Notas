variable "users" {
  description = "Map of users keyed by username. The key is the stable identity."
  type = map(object({
    name   = string
    email  = string
    groups = list(string)
  }))
}
