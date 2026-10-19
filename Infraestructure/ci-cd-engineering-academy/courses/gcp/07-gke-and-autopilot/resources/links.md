# Recursos — gcp-07

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing cambian).

## Oficiales (Google Cloud)

- **GKE overview**: `https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview`
- **GKE modes of operation (Standard vs Autopilot)**: `https://cloud.google.com/kubernetes-engine/docs/concepts/choose-cluster-mode`
- **Autopilot overview y limitaciones**: `https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview`
- **Autopilot — security capabilities and restrictions**: `https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security-capabilities`
- **GKE pricing**: `https://cloud.google.com/kubernetes-engine/pricing`
- **Release channels**: `https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels`
- **GKE VPC-native clusters**: `https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips`
- **Private clusters**: `https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept`

## Workload Identity Federation for GKE

- **Overview**: `https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity`
- **How-to (habilitar y usar)**: `https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity`
- **Troubleshooting**: `https://cloud.google.com/kubernetes-engine/docs/troubleshooting/workload-identity`
- **IAM — principal `svc.id.goog`**: `https://cloud.google.com/iam/docs/principal-identifiers`

## Networking (Ingress y Gateway API)

- **GKE Ingress**: `https://cloud.google.com/kubernetes-engine/docs/concepts/ingress`
- **Gateway API en GKE**: `https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api`
- **GatewayClass disponibles**: `https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api#gatewayclass`
- **Managed certificates**: `https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs`
- **BackendConfig / FrontendConfig (CRDs de GCE)**: `https://cloud.google.com/kubernetes-engine/docs/concepts/ingress#configuring-ingress`

## Terraform

- **`google_container_cluster`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster`
- **`google_container_node_pool`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool`
- **Módulo comunidad `terraform-google-kubernetes-engine`**: `https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest`

## Para contraste (AWS)

- **IRSA (IAM Roles for Service Accounts)**: `https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html`
- **EKS Pod Identity** (modelo nuevo, equivalente moderno de IRSA): `https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html`
- **EKS Fargate** (análogo parcial de Autopilot): `https://docs.aws.amazon.com/eks/latest/userguide/fargate.html`

## Local tooling

- **kind** (K8s local, para validar manifiestos sin cluster real): `https://kind.sigs.k8s.io/`
- **kubectl --dry-run=client**: `https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-em-dry-run-em-`
- **kubectl --dry-run=server**: requiere cluster real; útil contra kind.
- **yamllint**: `https://yamllint.readthedocs.io/`
- **Terraform CLI**: `https://developer.hashicorp.com/terraform/install`

## Checklist de verificación requerida en Fase 4

- Lista actualizada de **restricciones de Autopilot** (crece con el tiempo; algunas se relajan).
- Pricing vigente de **Autopilot** (modelo per-pod y sobrecargo exacto).
- Nombres actuales de **GatewayClass** (Google renombra ocasionalmente).
- Vigencia del término **"Workload Identity Federation for GKE"** (antes "Workload Identity"; podría volver a renombrar).
- Compatibilidad entre versiones del provider Terraform (`hashicorp/google`) y el API de GKE.
- Estado de **GKE Enterprise / Fleet** y features relevantes para multi-cluster.
