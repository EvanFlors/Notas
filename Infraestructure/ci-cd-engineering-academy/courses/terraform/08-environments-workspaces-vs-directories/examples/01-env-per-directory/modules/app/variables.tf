variable "environment" {
  description = "Name of the target environment (dev/stg/prod/...)."
  type        = string
  validation {
    condition     = length(var.environment) > 0 && length(var.environment) < 16
    error_message = "environment must be a non-empty string shorter than 16 chars."
  }
}

variable "project" {
  description = "Project / app name used as a prefix for every artifact."
  type        = string
  default     = "shop"
}

variable "replica_count" {
  description = "How many replicas of the app to render in the manifest."
  type        = number
  default     = 1
}

variable "instance_class_label" {
  description = "Opaque label describing the instance class (free of cloud specifics so the module stays portable)."
  type        = string
  default     = "small"
}

variable "out_dir" {
  description = "Directory where the manifest will be written. Must already exist or be creatable."
  type        = string
  default     = "out"
}
