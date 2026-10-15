variable "items" {
  description = "Lista de items. Internamente se transforma a map keyed por name."
  type = list(object({
    name = string
    tier = string
  }))

  validation {
    condition     = length(distinct([for i in var.items : i.name])) == length(var.items)
    error_message = "Los 'name' deben ser únicos (identidad del map)."
  }
}
