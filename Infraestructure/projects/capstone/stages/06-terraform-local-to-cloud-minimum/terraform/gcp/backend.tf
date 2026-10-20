# Partial backend: real bucket name is injected at
# `terraform init -backend-config=bucket=<name>`.
terraform {
  backend "gcs" {
    # bucket = "<set via -backend-config>"
    # prefix = "capstone/stage-06"
  }
}
