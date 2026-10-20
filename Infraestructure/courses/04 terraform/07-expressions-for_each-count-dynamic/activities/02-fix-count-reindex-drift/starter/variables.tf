variable "items" {
  description = "Lista de items. CUIDADO: identidad por posición es antipatrón; refactorizar a map/set keyed por name."
  type = list(object({
    name = string
    tier = string
  }))
}
