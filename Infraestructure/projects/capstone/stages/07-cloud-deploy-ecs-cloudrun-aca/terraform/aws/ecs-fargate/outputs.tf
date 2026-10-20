output "alb_dns_name" {
  description = "Public DNS of the ALB. GET http://<dns>/health should return 200 once the task is healthy."
  value       = aws_lb.api.dns_name
}

output "db_secret_arn" {
  description = "ARN of the DB DSN secret in Secrets Manager."
  value       = aws_secretsmanager_secret.db_dsn.arn
  sensitive   = true
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}
