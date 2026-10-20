# Recursos — aws-11

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso (los enlaces y versiones cambian).

## EKS oficial

- Documentación: `https://docs.aws.amazon.com/eks/`
- Precios (incluye el **$0.10/hora** del control plane): `https://aws.amazon.com/eks/pricing/`
- Best practices (serie oficial): `https://aws.github.io/aws-eks-best-practices/`
- EKS release calendar (versiones soportadas): `https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html`

## Herramientas de provisión

- **Terraform EKS module (oficial comunidad)**: `https://github.com/terraform-aws-modules/terraform-aws-eks`
- **eksctl**: `https://eksctl.io/`
- **AWS EKS Blueprints for Terraform**: `https://aws-ia.github.io/terraform-aws-eks-blueprints/`

## Acceso al cluster

- Access entries (anuncio y guía): `https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html`
- `aws-auth` ConfigMap (legacy, aún documentado): `https://docs.aws.amazon.com/eks/latest/userguide/auth-configmap.html`

## IRSA y Pod Identity

- IRSA: `https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html`
- EKS Pod Identity: `https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html`
- Comparación oficial IRSA vs Pod Identity: `https://docs.aws.amazon.com/eks/latest/userguide/service-accounts.html`

## Add-ons

- Managed add-ons: `https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html`
- AWS Load Balancer Controller: `https://kubernetes-sigs.github.io/aws-load-balancer-controller/`
- External DNS: `https://github.com/kubernetes-sigs/external-dns`
- EBS CSI driver: `https://github.com/kubernetes-sigs/aws-ebs-csi-driver`

## Autoscaling de nodos

- Karpenter: `https://karpenter.sh/`
- Cluster Autoscaler: `https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler`
- Comparación Karpenter vs CAS (blogs AWS): buscar "Karpenter vs Cluster Autoscaler" en el blog de AWS Containers.

## Local (sin coste)

- **kind** (Kubernetes IN Docker): `https://kind.sigs.k8s.io/`
- `minikube`: `https://minikube.sigs.k8s.io/`

## Fase 4 — verificaciones

- Vigencia de **access entries** como modo recomendado por defecto.
- Estado del add-on **eks-pod-identity-agent** (versión y clusters soportados).
- Versión mínima del **AWS SDK** que soporta Pod Identity nativamente.
- Última minor de Karpenter y rupturas vs v0.x → v1.x (CRDs renombrados).
