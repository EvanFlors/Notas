# Ejemplo 01 — EKS con Terraform blueprint + `eksctl` config

> Lectura y adaptación local. **Sin ejecución contra AWS.** Objetivo: ver una provisión real de EKS en dos sabores (Terraform y `eksctl`) y entender cada bloque.

## 1. Contexto

Hay dos caminos canónicos para provisionar EKS:

- **Terraform** con el módulo oficial `terraform-aws-modules/eks/aws` (abstracción de alto nivel, mantiene cluster + node groups + add-ons + access entries + IRSA roles).
- **`eksctl`** con un YAML declarativo (una sola herramienta, foco EKS, menos abstracción pero más cercana al API de EKS).

Ambos acaban llamando a las mismas APIs. En equipos con Terraform ya en uso, se queda en Terraform. En POCs rápidos o cuando solo tocas EKS, `eksctl` es más corto.

## 2. Terraform (módulo oficial)

Archivo `main.tf` (**no ejecutar**, solo lectura):

```hcl
# versiones
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.60" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC via el módulo oficial, 3 AZ, public + private subnets.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "eks-demo"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # cost-saving para demo; 1 NAT en vez de 3

  # Tags requeridos por EKS para subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# Cluster EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20"

  cluster_name    = "eks-demo"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true   # para demo; en prod suele ser private
  enable_irsa                    = true   # habilita OIDC provider

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Managed node group por defecto
  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
    }
  }

  # Add-ons administrados (versiones las resuelve el módulo con la minor del cluster)
  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }

  # Access entries (modelo moderno; aws-auth queda off)
  authentication_mode = "API"

  access_entries = {
    admin_ci = {
      principal_arn = "arn:aws:iam::123456789012:role/ci-eks-admin"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
```

### Qué deberías mirar

- `cluster_version = "1.30"` — pinear la minor. Dejar `latest` dinámico es un fuente de drift.
- `enable_irsa = true` — crea el OIDC provider. Sin esto, no hay IRSA.
- `single_nat_gateway = true` — ahorro de ~$30/mes en NATs para demo. **En prod** suele ser `false` (NAT por AZ para resiliencia).
- `authentication_mode = "API"` — access entries puras, sin `aws-auth`. Alternativa: `"API_AND_CONFIG_MAP"` durante migración.
- `cluster_addons = { ... }` — add-ons como objetos administrados, no helm charts.
- Los ARNs son **ficticios**: `123456789012` es la cuenta canónica de ejemplos AWS, usar siempre `123456789012` o similar; **nunca** poner una cuenta real en código de ejemplo.

### Qué cuesta este stack si lo levantas (referencia)

- **Control plane EKS:** $0.10/hora × 1 cluster = ~$73/mes.
- **2 × t3.medium on-demand:** ~$60/mes.
- **1 NAT gateway + tráfico:** $32/mes base.
- **Total mínimo:** ~$165/mes **mientras esté arriba**.

Por eso este ejemplo es **para leer**. Para practicar, usa `kind` (ver actividad 01).

## 3. `eksctl` config (equivalente)

Archivo `eksctl-config.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: eks-demo
  region: us-east-1
  version: "1.30"

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single   # equivalente a single_nat_gateway=true
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

iam:
  withOIDC: true   # habilita IRSA

managedNodeGroups:
  - name: general
    instanceType: t3.medium
    minSize: 2
    maxSize: 4
    desiredCapacity: 2
    privateNetworking: true
    labels:
      role: general

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
          accessScope:
            type: cluster
```

### Equivalencias clave

| Terraform | `eksctl` |
|-----------|----------|
| `enable_irsa = true` | `iam.withOIDC: true` |
| `cluster_addons = {...}` | `addons: [...]` |
| `authentication_mode = "API"` | `accessConfig.authenticationMode: API` |
| `eks_managed_node_groups` | `managedNodeGroups` |
| `single_nat_gateway = true` | `vpc.nat.gateway: Single` |

### Validación sin AWS

Puedes validar la **sintaxis** del YAML `eksctl` sin crear nada:

```bash
eksctl create cluster --config-file=eksctl-config.yaml --dry-run
```

Y la **sintaxis** del Terraform sin credenciales útiles:

```bash
terraform init -backend=false
terraform validate
```

(En la actividad 01 esto se cubre explícitamente.)

## 4. Qué NO está aquí (y por qué)

- **AWS Load Balancer Controller:** se instala vía helm chart o add-on separado; se omite para que el ejemplo quepa.
- **Karpenter:** ver `../03-karpenter-provisioner/`.
- **IRSA role concreto:** ver `../02-irsa-s3-access-from-pod/`.

## 5. Preguntas de autocomprobación

1. ¿Por qué `single_nat_gateway = true` es aceptable en demo pero no en prod?
2. ¿Qué pasa si cambias `authentication_mode` de `API_AND_CONFIG_MAP` a `API` con `aws-auth` todavía poblado?
3. ¿Por qué `vpc-cni` y `coredns` aparecen como add-ons si son "default"? (Pista: versioning y managed upgrades.)
4. ¿Qué cambiaría si quisieras **private endpoint only** (sin acceso público al API server)?
