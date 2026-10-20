variable "rules" {
  description = "List of ingress rules. proto defaults to tcp; cidrs defaults to [0.0.0.0/0]."
  type = list(object({
    from  = number
    to    = number
    proto = optional(string)
    cidrs = optional(list(string))
    desc  = optional(string)
  }))
}
