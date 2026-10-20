# Partial backend: real values (bucket, dynamodb_table, region) are injected at
# `terraform init -backend-config=...` time. Never commit real bucket names.
terraform {
  backend "s3" {
    # bucket         = "<set via -backend-config>"
    # key            = "capstone/stage-06/terraform.tfstate"
    # region         = "<set via -backend-config>"
    # dynamodb_table = "<set via -backend-config>"
    # encrypt        = true
  }
}
