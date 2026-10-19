// Starter Terraform for aws-10-01-fastapi-on-ecs-fargate.
// Fill in the TODO blocks. Do NOT apply against a real AWS account.
// Validate locally with:  terraform init -backend=false && terraform validate

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
  region                      = "eu-west-1"
  access_key                  = "FAKEEXAMPLEKEY"
  secret_key                  = "FAKEEXAMPLESECRET"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variable "vpc_id" {
  type    = string
  default = "vpc-00000000000000000"
}

variable "private_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000003", "subnet-00000000000000004"]
}

variable "image_uri" {
  type    = string
  default = "000000000000.dkr.ecr.eu-west-1.amazonaws.com/capstone-api:v1"
}

// ----------------------------------------------------------------------------
// IAM — execution role (ECS pulls image + writes logs) vs task role (app code).
// These are already provided; do NOT merge them.
// ----------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "capstone-api-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "capstone-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

// ----------------------------------------------------------------------------
// Networking — SG for ALB (open 80) and SG for tasks (only ALB -> 8000).
// ----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name   = "capstone-api-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "task" {
  name   = "capstone-api-task"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "api" {
  name               = "capstone-api"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/capstone-api"
  retention_in_days = 14
}

// ============================================================================
// TODO 1 — ECS cluster.
//
//   resource "aws_ecs_cluster" "main" {
//     name = "capstone"
//   }
// ============================================================================


// ============================================================================
// TODO 2 — ALB target group.
//
// Must set target_type = "ip" (Fargate tasks have no instance_id; ECS registers
// them by ENI private IP). A health_check block targeting /health is expected.
// ============================================================================


// ============================================================================
// TODO 3 — ECS task definition.
//
// Must mirror the values from task-definition.json:
//   - family                    = "capstone-api"
//   - requires_compatibilities  = ["FARGATE"]
//   - network_mode              = "awsvpc"
//   - cpu                       = "512"
//   - memory                    = "1024"
//   - execution_role_arn        = aws_iam_role.execution.arn
//   - task_role_arn             = aws_iam_role.task.arn
//   - container_definitions     = jsonencode([{ ... }])
// ============================================================================


// ============================================================================
// TODO 4 — ECS service.
//
// Must set:
//   - launch_type       = "FARGATE"
//   - desired_count     >= 1
//   - network_configuration { subnets, security_groups, assign_public_ip = false }
//   - load_balancer { target_group_arn, container_name, container_port }
//   - depends_on = [aws_lb_listener.api]
// ============================================================================
