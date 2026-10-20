packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
  }
}

variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region in which the AMI is built."
}

variable "app_version" {
  type        = string
  default     = "0.1.0"
  description = "App version baked into the AMI name and passed to the playbook."
}

source "amazon-ebs" "al2023" {
  region        = var.region
  instance_type = "t3.micro"
  ami_name      = "webapp-${var.app_version}-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"

  tags = {
    Name      = "webapp-${var.app_version}"
    BuiltBy   = "packer"
    BaseAMI   = "al2023"
    ManagedBy = "ansible"
  }
}

build {
  name    = "webapp"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    user          = "ec2-user"
    use_proxy     = false
    extra_arguments = [
      "--extra-vars", "app_version=${var.app_version}",
      "-v"
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
