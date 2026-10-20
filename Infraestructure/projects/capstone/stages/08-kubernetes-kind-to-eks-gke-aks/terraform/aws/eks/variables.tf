variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region where the EKS cluster will be provisioned."
}

variable "cluster_name" {
  type        = string
  default     = "capstone"
  description = "EKS cluster name (prefijado por ambiente en overlays reales)."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30"
  description = "Minor del control plane EKS."
}

variable "subnet_ids" {
  type        = list(string)
  default     = ["subnet-DUMMY-a", "subnet-DUMMY-b"]
  description = "Subnets privadas donde vive el node group (del stage 6)."
}

variable "node_desired" {
  type        = number
  default     = 2
  description = "Nodos deseados en el managed node group."
}
