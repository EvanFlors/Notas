variable "length" {
  description = "Number of words in the generated pet name."
  type        = number
  default     = 2
  validation {
    condition     = var.length >= 1 && var.length <= 5
    error_message = "length must be between 1 and 5."
  }
}
