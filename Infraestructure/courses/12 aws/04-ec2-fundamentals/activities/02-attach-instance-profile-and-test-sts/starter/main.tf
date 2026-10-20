terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Trust policy (EC2 service).
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# TODO 1 — Policy MINIMA de aplicacion.
# Debe permitir solo `ssm:GetParameter` sobre el ARN
#   arn:aws:ssm:${var.region}:${var.account_id_dummy}:parameter${var.parameter_prefix}/*
# NO uses Action="*" ni Resource="*".
# Pista: usa `data "aws_iam_policy_document"` + `resource "aws_iam_role_policy"`.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "app_min" {
  statement {
    sid     = "ReadDemoParameters"
    effect  = "Allow"
    actions = [] # TODO
    resources = [
      # TODO: construye el ARN con var.region, var.account_id_dummy y var.parameter_prefix
    ]
  }
}

resource "aws_iam_role_policy" "app_min" {
  name   = "${var.name_prefix}-min"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.app_min.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-profile"
  role = aws_iam_role.ec2.name
}
