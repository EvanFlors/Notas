output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "Nombre del cluster EKS."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "Endpoint del apiserver."
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
  description = "Comando sugerido para poblar ~/.kube/config."
}
