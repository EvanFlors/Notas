terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

resource "random_id" "adopted" {
  byte_length = 4
}

import {
  to = random_id.adopted
  id = "AAAAAA"
}
