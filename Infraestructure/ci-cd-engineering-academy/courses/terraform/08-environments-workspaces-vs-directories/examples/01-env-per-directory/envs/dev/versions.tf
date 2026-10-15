terraform {
  required_version = ">= 1.3.0"
  # Local backend used for didactic purposes. In production this would be a
  # per-environment remote backend (own bucket/key/credentials).
  backend "local" {
    path = "terraform.tfstate"
  }
}
