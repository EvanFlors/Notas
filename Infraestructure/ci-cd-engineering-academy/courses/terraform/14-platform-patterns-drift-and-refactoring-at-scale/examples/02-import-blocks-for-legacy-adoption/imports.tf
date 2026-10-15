# Bulk adoption of three pre-existing files via import {} blocks.
# After `terraform plan -generate-config-out=generated.tf`, inspect and clean
# generated.tf, then `terraform apply`.

import {
  to = local_file.alpha
  id = "/tmp/tf14-ex02-legacy/alpha.conf"
}

import {
  to = local_file.beta
  id = "/tmp/tf14-ex02-legacy/beta.conf"
}

import {
  to = local_file.gamma
  id = "/tmp/tf14-ex02-legacy/gamma.conf"
}
