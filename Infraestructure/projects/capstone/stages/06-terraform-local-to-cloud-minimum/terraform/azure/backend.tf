# Partial backend: resource_group_name, storage_account_name and container_name
# are injected at `terraform init -backend-config=...` time.
terraform {
  backend "azurerm" {
    # resource_group_name  = "<set via -backend-config>"
    # storage_account_name = "<set via -backend-config>"
    # container_name       = "<set via -backend-config>"
    # key                  = "capstone/stage-06.tfstate"
  }
}
