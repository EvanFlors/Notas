variable "name" {
  description = "Logical name of the greeting (used in filename and content). Must be DNS-safe."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must match ^[a-z][a-z0-9-]{1,30}$ (platform naming convention)."
  }
}

variable "message" {
  description = "Greeting message content."
  type        = string
  default     = "Hello from the golden greeter module"
}

variable "owner" {
  description = "Owning team (platform tag). Required."
  type        = string

  validation {
    condition     = length(var.owner) > 0
    error_message = "owner tag is mandatory by platform contract."
  }
}

variable "output_dir" {
  description = "Directory where the greeting file is created."
  type        = string
  default     = "/tmp/greeter-out"
}
