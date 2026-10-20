// Capstone stage 07 — ECS Fargate + ALB + RDS Postgres + Secrets Manager.
// Deploys the signed image from stage 05. Pins the image BY DIGEST.
//
// WARNING: `apply` COSTS MONEY (~$50/mo if left running). CI only runs `plan`.
// Always finish with: bash ../../../../scripts/cleanup-aws.sh

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      capstone = "07"
      project  = var.project_tag
      stage    = "cloud-deploy"
    }
  }
}

// ----------------------------------------------------------------------------
// IAM: execution role (ECS/Fargate itself) vs task role (the running process).
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
  name               = "${var.project_tag}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Allow the execution role to resolve the DB secret when launching the task.
resource "aws_iam_role_policy" "execution_secret_read" {
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.db_dsn.arn
    }]
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.project_tag}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

// ----------------------------------------------------------------------------
// Networking: SGs for ALB, tasks, RDS.
// ----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name   = "${var.project_tag}-alb"
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
  name   = "${var.project_tag}-task"
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

resource "aws_security_group" "db" {
  name   = "${var.project_tag}-db"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.task.id]
  }
}

// ----------------------------------------------------------------------------
// RDS Postgres (private, no public IP).
// ----------------------------------------------------------------------------
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
  storage_type           = "gp3"
  username               = var.db_username
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  storage_encrypted      = true
}

// ----------------------------------------------------------------------------
// Secrets Manager: the DSN only — password itself is derived in-cluster.
// ----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_dsn" {
  name                    = "${var.project_tag}/db-dsn"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_dsn" {
  secret_id = aws_secretsmanager_secret.db_dsn.id
  secret_string = jsonencode({
    dsn = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.pg.address}:5432/postgres"
  })
}

// ----------------------------------------------------------------------------
// ALB + target group (target_type = ip, mandatory for Fargate).
// ----------------------------------------------------------------------------
resource "aws_lb" "api" {
  name               = "${var.project_tag}-alb"
  internal           = false
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

// ----------------------------------------------------------------------------
// ECS cluster, task definition, service.
// ----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_tag}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_tag}-cluster"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_tag}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.image_digest
      essential = true
      portMappings = [
        { containerPort = 8000, protocol = "tcp" }
      ]
      secrets = [
        { name = "APP_DB_DSN", valueFrom = "${aws_secretsmanager_secret.db_dsn.arn}:dsn::" }
      ]
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
