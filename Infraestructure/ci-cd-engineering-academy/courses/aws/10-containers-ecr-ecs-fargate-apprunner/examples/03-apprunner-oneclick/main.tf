// Example 03 — App Runner service pointing to an ECR image.
// NEVER applied against real AWS; used with `terraform validate` only.

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "FAKEEXAMPLEKEY"
  secret_key                  = "FAKEEXAMPLESECRET"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variable "image_uri" {
  type    = string
  default = "000000000000.dkr.ecr.us-east-1.amazonaws.com/capstone-api:v1"
}

// App Runner needs an "access role" to pull the image from a private ECR repo.
// This is the App Runner equivalent of the ECS execution role.
data "aws_iam_policy_document" "apprunner_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apprunner_ecr_access" {
  name               = "capstone-apprunner-ecr-access"
  assume_role_policy = data.aws_iam_policy_document.apprunner_assume.json
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

// Separate "instance role" — App Runner equivalent of ECS task role (what the app code uses).
data "aws_iam_policy_document" "apprunner_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apprunner_instance" {
  name               = "capstone-apprunner-instance"
  assume_role_policy = data.aws_iam_policy_document.apprunner_tasks_assume.json
}

resource "aws_apprunner_service" "api" {
  service_name = "capstone-api"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    auto_deployments_enabled = false

    image_repository {
      image_identifier      = var.image_uri
      image_repository_type = "ECR"

      image_configuration {
        port = "8000"
        runtime_environment_variables = {
          APP_ENV = "prod"
        }
      }
    }
  }

  instance_configuration {
    cpu               = "1024"
    memory            = "2048"
    instance_role_arn = aws_iam_role.apprunner_instance.arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

output "apprunner_url" {
  value       = aws_apprunner_service.api.service_url
  description = "HTTPS URL that App Runner issues; TLS cert is managed by AWS."
}
