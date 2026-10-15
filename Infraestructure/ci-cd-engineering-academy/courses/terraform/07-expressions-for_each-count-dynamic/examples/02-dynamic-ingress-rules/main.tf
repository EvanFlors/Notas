terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  # Normalizar reglas: default proto="tcp" si falta, cidrs = ["0.0.0.0/0"] si falta.
  rules_normalized = [
    for r in var.rules : {
      from  = r.from
      to    = r.to
      proto = try(r.proto, "tcp")
      cidrs = try(r.cidrs, ["0.0.0.0/0"])
      desc  = try(r.desc, "")
    }
  ]
}

resource "local_file" "sg_rendered" {
  filename        = "${path.module}/out/web-sg.rendered.tf"
  file_permission = "0644"
  content = templatefile("${path.module}/sg.tftpl", {
    name  = "web"
    rules = local.rules_normalized
  })
}

output "rules_count" {
  value = length(local.rules_normalized)
}

output "rules_rendered" {
  value = local_file.sg_rendered.filename
}
