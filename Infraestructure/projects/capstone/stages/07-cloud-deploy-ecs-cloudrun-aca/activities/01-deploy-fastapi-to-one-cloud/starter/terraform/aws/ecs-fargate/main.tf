// Starter — capstone 07 activity 01 — AWS ECS Fargate.
// Four TODO blocks must be solved to pass the validator.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      capstone = "07"
      project  = var.project_tag
    }
  }
}

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
  name               = "${var.project_tag}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "alb" {
  name   = "${var.project_tag}-alb"
  vpc_id = var.vpc_id
  ingress { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0,  to_port = 0,  protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "task" {
  name   = "${var.project_tag}-task"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_tag}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "pg" {
  identifier             = "${var.project_tag}-pg"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.db.name
  publicly_accessible    = false
  skip_final_snapshot    = true
}

resource "aws_lb" "api" {
  name               = "${var.project_tag}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_tag}-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path    = "/health"
    matcher = "200"
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

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_tag}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_tag}-cluster"
}

// ---------------------------------------------------------------------------
// TODO 1 — Pin the image BY DIGEST (not by tag).
// Replace the placeholder below with var.image_digest and make sure
// variables.tf default uses "@sha256:" (already set by default).
// Hint: the string you pass to container_definitions[].image must contain
// "@sha256:" literally.
// ---------------------------------------------------------------------------
locals {
  // TODO 1: replace null with var.image_digest
  image_ref = null
}

// ---------------------------------------------------------------------------
// TODO 2 — Create the TASK role (not the execution role).
// It is the identity your Python code assumes when it calls AWS SDKs.
// Must assume the ecs-tasks service principal just like the execution role.
// Resource type: aws_iam_role, name: "${var.project_tag}-task".
// ---------------------------------------------------------------------------

// TODO 2 — declare resource "aws_iam_role" "task" HERE.

// ---------------------------------------------------------------------------
// TODO 3 — Create the DB DSN secret in Secrets Manager + a policy on the
// EXECUTION role allowing it to call secretsmanager:GetSecretValue on that
// secret ARN. Store the DSN as JSON {"dsn": "postgresql://..."}.
// Resources: aws_secretsmanager_secret, aws_secretsmanager_secret_version,
// aws_iam_role_policy (attached to aws_iam_role.execution).
// ---------------------------------------------------------------------------

// TODO 3 — declare the three resources HERE.

// ---------------------------------------------------------------------------
// TODO 4 — In container_definitions, inject APP_DB_DSN via the "secrets"
// field (NOT via "environment" with a plaintext value). The valueFrom
// must reference the secret ARN with ":dsn::" suffix to pick the JSON key.
// Also set execution_role_arn and task_role_arn (hint: use the roles above).
// ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_tag}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  // TODO 4: set execution_role_arn and task_role_arn
  execution_role_arn = null
  task_role_arn      = null

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = local.image_ref
      essential = true
      portMappings = [{ containerPort = 8000, protocol = "tcp" }]

      // TODO 4: add a `secrets` entry injecting APP_DB_DSN from the secret.
      secrets = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "${var.project_tag}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"
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
