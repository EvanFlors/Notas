bucket         = "acme-tf-state-dev"
key            = "app-payments/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "acme-tf-lock-dev"
encrypt        = true
