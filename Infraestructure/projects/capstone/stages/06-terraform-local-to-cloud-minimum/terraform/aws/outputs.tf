output "vpc_id" {
  description = "VPC id consumed by stage 7 runtime."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnets (NAT, ALB)."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Private subnets (ECS tasks, future RDS)."
  value       = [for s in aws_subnet.private : s.id]
}

output "base_security_group_id" {
  description = "Base egress-only SG."
  value       = aws_security_group.base.id
}

output "registry_url" {
  description = "ECR repo URL for `docker push`."
  value       = aws_ecr_repository.app.repository_url
}

output "state_bucket" {
  description = "S3 bucket backing the terraform remote state."
  value       = aws_s3_bucket.state.bucket
}

output "state_lock_table" {
  description = "DynamoDB table backing terraform state locking."
  value       = aws_dynamodb_table.lock.name
}
