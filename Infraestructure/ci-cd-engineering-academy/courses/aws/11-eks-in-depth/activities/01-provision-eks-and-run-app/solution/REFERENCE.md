# REFERENCE — aws-11-01-provision-eks-and-run-app

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `terraform/main.tf` (modelo)

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "aws-11-demo"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20"

  cluster_name    = "aws-11-demo"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
    }
  }

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }

  authentication_mode = "API"

  access_entries = {
    admin_ci = {
      principal_arn = "arn:aws:iam::123456789012:role/ci-eks-admin"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}
```

## `eksctl/cluster.yaml` (modelo)

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: aws-11-demo
  region: us-east-1
  version: "1.30"

vpc:
  cidr: 10.0.0.0/16
  nat: { gateway: Single }
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

iam:
  withOIDC: true

managedNodeGroups:
  - name: general
    instanceType: t3.medium
    minSize: 2
    maxSize: 4
    desiredCapacity: 2
    privateNetworking: true

addons:
  - name: coredns
  - name: kube-proxy
  - name: vpc-cni
  - name: aws-ebs-csi-driver
  - name: eks-pod-identity-agent

accessConfig:
  authenticationMode: API
  accessEntries:
    - principalARN: arn:aws:iam::123456789012:role/ci-eks-admin
      type: STANDARD
      accessPolicies:
        - policyARN: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
          accessScope: { type: cluster }
```

## `k8s/app.yaml` (modelo)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports: [{ containerPort: 80 }]
          resources:
            requests: { cpu: "50m", memory: "64Mi" }
            limits:   { cpu: "200m", memory: "128Mi" }
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: demo
spec:
  type: ClusterIP
  selector: { app: web }
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: demo
  annotations:
    # Interpretado por AWS Load Balancer Controller en EKS; ignorado en kind.
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - host: demo.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port: { number: 80 }
```

## `docs/EKS_PLAN.md` (modelo, extracto)

```
# EKS Plan — aws-11-demo

## Arquitectura

   VPC 10.0.0.0/16 en 3 AZ (private + public subnets, single NAT para demo)
     └── EKS 1.30 control plane (managed)
          ├── MNG general: 2–4 x t3.medium on-demand
          └── Add-ons: coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver,
                        eks-pod-identity-agent

## Add-ons y por qué
- coredns, kube-proxy, vpc-cni: baseline obligatorio.
- aws-ebs-csi-driver: PVCs dinámicos.
- eks-pod-identity-agent: habilita Pod Identity (preferido sobre IRSA para greenfield).

## Lo que esta actividad NO prueba (kind != EKS)
- OIDC provider real → IRSA real.
- ALB real (la anotación del Ingress es ignorada por kind).
- VPC CNI → en kind el CNI es kindnet.
- Managed add-ons administrados por AWS (en kind no existe el concepto).
- Access entries (es API de EKS).
```

## `docs/ADR.md` (modelo, extracto)

```
# ADR — aws-11-demo

## Decision 1 — Modelo de cómputo

Status: Accepted
Context: Backend web stateless con tráfico predecible, 2–4 pods por servicio.
Options considered:
  - Managed node groups
  - Self-managed node groups
  - Fargate profiles
Decision: Managed node groups.
Rationale: Baseline predecible, upgrades gestionados por AWS, PDB-aware.
  Fargate descartado por el overhead por pod y la ausencia de DaemonSets
  (necesarios para instalar add-ons de red/observabilidad). Self-managed
  descartado por no haber requisitos de AMI custom.
Consequences: Perdemos aislamiento por micro-VM que da Fargate. Si entran
  tenants no confiables, revisitar la decisión.

## Decision 2 — Autoscaler de nodos

Status: Accepted
Options considered: Cluster Autoscaler vs Karpenter.
Decision: Karpenter.
Rationale: Flexibilidad de tipos de instancia, latencia de scale-up más baja,
  consolidation nativa, mezcla on-demand/spot por pod.
Consequences: Curva de aprendizaje de los CRDs NodePool/EC2NodeClass; menos
  tiempo en producción que CAS pero suficiente a 2026.

## Decision 3 — Modo de acceso al cluster

Status: Accepted
Options considered: aws-auth ConfigMap vs EKS access entries.
Decision: Access entries (authentication_mode = "API").
Rationale: Auditables en CloudTrail, gestionables desde Terraform, no se
  rompen por un edit malo del ConfigMap. aws-auth queda solo si una
  dependencia legacy lo pide.
Consequences: Requiere cluster >= 1.23 (ya lo cumplimos con 1.30).
```

## Comentarios de autoevaluación

- Si tu ADR tiene **menos** de 3 decisiones, repítelo. Si cada decisión no
  nombra al menos 2 alternativas rechazadas, repítelo también.
- Si los pods del `kind` no están `Ready`, el fallo suele ser `resources.limits`
  demasiado bajos o un typo en `selector`/`labels`.
- Si `terraform validate` falla, falta casi siempre `required_providers` o la
  versión del módulo no está pineada.
