terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

resource "local_file" "new_name" {
  filename = "/tmp/tf-09-01/greeting.txt"
  content  = "hola desde tf-09-01\n"
}

moved {
  from = local_file.old_name
  to   = local_file.new_name
}
