terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Credenciales se toman del entorno. Este modulo NO se aplica en AWS;
  # solo se usa para `terraform plan` local con credenciales fake.
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

variable "github_org" {
  description = "GitHub organization / owner of the repo"
  type        = string
  default     = "example-org"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "example-repo"
}

variable "github_branch" {
  description = "Branch allowed to assume the role"
  type        = string
  default     = "main"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint ilustrativo. Para uso real, obtener el actual de la doc oficial.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "gha_deploy" {
  name = "gha-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "gha_deploy" {
  name = "gha-deploy-inline"
  role = aws_iam_role.gha_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::my-site",
          "arn:aws:s3:::my-site/*"
        ]
      }
    ]
  })
}

output "role_arn" {
  value       = aws_iam_role.gha_deploy.arn
  description = "ARN to put in configure-aws-credentials@v4 role-to-assume"
}
