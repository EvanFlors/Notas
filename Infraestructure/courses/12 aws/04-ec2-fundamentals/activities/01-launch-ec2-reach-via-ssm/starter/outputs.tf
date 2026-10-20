output "instance_id" {
  description = "ID de la EC2 (en modo lab es un placeholder: no se aplica)."
  value       = aws_instance.app.id
}

output "ssm_start_session_command" {
  description = "Comando para abrir sesion SSM una vez aplicado."
  value       = "aws ssm start-session --target ${aws_instance.app.id}"
}

output "iam_role_arn" {
  description = "ARN del rol IAM asumido por la EC2."
  value       = aws_iam_role.ec2_ssm.arn
}
