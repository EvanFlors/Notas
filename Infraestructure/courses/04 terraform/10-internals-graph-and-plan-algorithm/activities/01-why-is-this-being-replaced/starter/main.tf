terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

# Starter buggy: cada plan propone replace.
# Investigalo con `terraform show -json plan.out | jq`.
resource "null_resource" "boot" {
  triggers = {
    # El autor quería "recrear si cambia la configuración de boot",
    # pero la implementación tiene un bug sutil.
    boot_ts = timestamp()
    config  = "default-boot-config-v1"
  }
}
