# az-07 — Enlaces y lecturas

## Documentación oficial AKS

- [AKS overview](https://learn.microsoft.com/azure/aks/intro-kubernetes)
- [AKS best practices (operator / developer)](https://learn.microsoft.com/azure/aks/best-practices)
- [Node pools (system vs user)](https://learn.microsoft.com/azure/aks/use-system-pools)
- [Spot node pools](https://learn.microsoft.com/azure/aks/spot-node-pool)
- [Virtual Nodes con ACI](https://learn.microsoft.com/azure/aks/virtual-nodes)
- [Azure CNI vs Azure CNI Overlay vs kubenet](https://learn.microsoft.com/azure/aks/concepts-network)
- [Cluster autoscaler](https://learn.microsoft.com/azure/aks/cluster-autoscaler)
- [Node Autoprovisioning (NAP)](https://learn.microsoft.com/azure/aks/node-autoprovision) *(verificar preview/GA)*
- [Upgrades: surge y max-unavailable](https://learn.microsoft.com/azure/aks/upgrade-cluster)

## Workload Identity

- [Overview](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Deploy on AKS](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster)
- [Federated identity credential (concepto)](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [Migrar desde Pod Identity v1](https://learn.microsoft.com/azure/aks/workload-identity-migrate-from-pod-identity)
- Proyecto upstream OSS: [Azure Workload Identity (SIG Auth)](https://azure.github.io/azure-workload-identity/)

## AAD Pod Identity v1 (deprecado — referencia)

- [Anuncio de deprecación](https://github.com/Azure/aad-pod-identity#-announcement)
- Repo histórico: [Azure/aad-pod-identity](https://github.com/Azure/aad-pod-identity)

## Add-ons y extensiones

- [Managed add-ons de AKS (catálogo)](https://learn.microsoft.com/azure/aks/integrations)
- [App Routing (nginx + managed cert)](https://learn.microsoft.com/azure/aks/app-routing)
- [CSI Secrets Store con Azure provider](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver)
- [Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
- [Microsoft Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)
- [Dapr extension](https://learn.microsoft.com/azure/aks/dapr)
- [GitOps con Flux v2 (`az k8s-extension`)](https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2)
- [AGIC — Application Gateway Ingress Controller](https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview)

## Terraform

- [`azurerm_kubernetes_cluster`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [`azurerm_kubernetes_cluster_node_pool`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool)
- [`azurerm_user_assigned_identity`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity)
- [`azurerm_federated_identity_credential`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential)

## Comparativas

- [AKS vs EKS vs GKE — matriz de features](https://learn.microsoft.com/azure/aks/kubernetes-walkthrough)
- [IRSA (EKS) vs Workload Identity (AKS)](https://azure.github.io/azure-workload-identity/docs/introduction.html)
