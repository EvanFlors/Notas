// Example 02 — ECS Fargate service + ALB (reference Terraform).
// NEVER applied against a real AWS account from this module; used with
// `terraform validate` only.

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
  region = "us-east-1"
  // Do not touch real AWS — these fake creds let `plan` go further without AWS calls.
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
  default = "000000000000.dkr.ecr.us-east-1.amazonaws.com/capstone-api:v1"
  // NB: 000000000000 is NOT a real AWS account id; it's a placeholder.
}

// ---------------------------------------------------------------------------
// IAM roles — execution role (ECS pulls + logs) vs task role (app code).
// ---------------------------------------------------------------------------

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

// Example of a narrow task role policy — read-only S3 for a reports bucket.
data "aws_iam_policy_document" "task_app" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::capstone-reports", "arn:aws:s3:::capstone-reports/*"]
  }
}

resource "aws_iam_role_policy" "task_app" {
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_app.json
}

// ---------------------------------------------------------------------------
// Networking: SG for ALB (open 80 world) and SG for tasks (only ALB → 8000).
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// ALB + listener + target group (target_type = "ip" is required for Fargate).
// ---------------------------------------------------------------------------

resource "aws_lb" "api" {
  name               = "capstone-api"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "api" {
  name        = "capstone-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
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

// ---------------------------------------------------------------------------
// CloudWatch Logs group for the awslogs driver.
// ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/capstone-api"
  retention_in_days = 14
}

// ---------------------------------------------------------------------------
// ECS cluster + Fargate task definition + service.
// ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "capstone"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "capstone-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.image_uri
      essential = true
      portMappings = [
        { containerPort = 8000, protocol = "tcp" }
      ]
      environment = [
        { name = "APP_ENV", value = "prod" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "capstone-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.api]
}
