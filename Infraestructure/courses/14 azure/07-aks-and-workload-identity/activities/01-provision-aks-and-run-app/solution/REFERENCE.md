# REFERENCE — az-07-01-provision-aks-and-run-app

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `terraform/main.tf` (modelo)

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "11111111-1111-1111-1111-111111111111"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-az07-demo"
  location = "westeurope"
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "mi-az07-aks"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-az07-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "az07demo"
  kubernetes_version  = "1.30"
  sku_tier            = "Free"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [
      "22222222-2222-2222-2222-222222222222",
    ]
    azure_rbac_enabled = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    zones                        = ["1", "2", "3"]
    only_critical_addons_enabled = true
    auto_scaling_enabled         = true
    min_count                    = 3
    max_count                    = 5
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = "Standard_D4s_v5"
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = 2
  max_count             = 8
  mode                  = "User"
}
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
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
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
  selector:
    app: web
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
    # Interpretado por App Routing en AKS; ignorado en kind.
    kubernetes.io/ingress.class: webapprouting.kubernetes.azure.com
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
                port:
                  number: 80
```

## `docs/AKS_PLAN.md` (modelo, extracto)

```
# AKS Plan — az-07-demo

## Arquitectura

   Resource group rg-az07-demo (westeurope)
     └── AKS 1.30 control plane (Free tier, managed)
          ├── system pool: 3-5 x Standard_D2s_v5, zones 1-2-3, only_critical_addons
          ├── user pool "apps": 2-8 x Standard_D4s_v5, autoscaling
          └── Networking: Azure CNI Overlay + Cilium network policy
     └── UA-MI mi-az07-aks (identidad del cluster, UserAssigned)

## Add-ons previstos

- key_vault_secrets_provider: montar secretos de Key Vault como volumen.
- workload_identity_enabled + oidc_issuer_enabled: foundation para la actividad 02.
- (produccion real) oms_agent → Container Insights.
- (produccion real) web_app_routing → ingress nginx gestionado.
- (produccion real) microsoft_defender → Defender for Containers.

## Lo que esta actividad NO prueba (kind != AKS)

- OIDC issuer real + Workload Identity real (en kind no hay Entra ni MI).
- App Routing / AGIC reales (la anotacion del Ingress es ignorada por kind).
- Azure CNI Overlay (en kind el CNI es kindnet).
- Entra ID + Azure RBAC for Kubernetes (en kind la auth es el cert admin local).
- Container Insights / Defender / Key Vault CSI reales.
```

## `docs/ADR.md` (modelo, extracto)

```
# ADR — az-07-demo

## Decision 1 — Mix de node pools

Status: Accepted
Context: Backend web stateless + CI jobs ocasionales, trafico predecible.
Options considered:
  - Solo system pool
  - System + 1 user pool
  - System + user pool + Spot pool
  - System + user pool + Virtual Nodes
Decision: System + 1 user pool "apps".
Rationale: El system pool queda limpio para pods criticos (only_critical_addons_enabled);
  el user pool escala para la app. Spot y Virtual Nodes se descartan por ahora:
  no hay workloads idempotentes/batch que justifiquen Spot, y los picos no son tan
  explosivos como para necesitar ACI burst.
Consequences: Pagamos VMSS por el user pool incluso vacio. Si en el futuro
  aparece un batch nocturno, revisitar Spot.

## Decision 2 — Modo de CNI

Status: Accepted
Options considered: Azure CNI plano, Azure CNI Overlay, kubenet.
Decision: Azure CNI Overlay.
Rationale: El VNet corporativo tiene subnets apretados; CNI plano consumiria
  una IP por pod del subnet y escalaria mal. Overlay mantiene la performance
  de Azure CNI pero asigna IPs de pod de un CIDR interno. kubenet queda
  descartado por legacy y falta de features modernas.
Consequences: Pods no son direccionables desde fuera del cluster con su IP
  "nativa" del VNet (hay que ir via Service/Ingress), lo cual es un no-problema
  para esta app.

## Decision 3 — Modo de acceso al cluster

Status: Accepted
Options considered: Entra RBAC + local_account_disabled vs modo mixto vs cuentas locales.
Decision: Entra ID + Azure RBAC for Kubernetes, local_account_disabled = true.
Rationale: Un unico plano de autenticacion (Entra) y de autorizacion (Azure RBAC).
  Nada de kubeconfig con cert admin flotando. Role assignments auditables en
  CloudTrail/Activity Log. Break-glass: un Entra group dedicado con Cluster Admin
  Role, cuyo acceso esta en PIM con aprobacion y expiracion.
Consequences: Si Entra ID esta caido, no entras al cluster. Mitigacion:
  break-glass en PIM + plan documentado + simulacro semestral.
```

## Comentarios de autoevaluación

- Si tu ADR tiene **menos** de 3 decisiones, repítelo. Si cada decisión no
  nombra al menos 2 alternativas rechazadas, repítelo también.
- Si los pods del `kind` no están `Ready`, el fallo suele ser `resources.limits`
  demasiado bajos o un typo en `selector`/`labels`.
- Si `terraform validate` falla, falta casi siempre `required_providers`, la
  versión del `azurerm` o el bloque `features {}` dentro del provider.
- Si tu `main.tf` tiene un UUID que **no** es `0000...` o `1111...` o `2222...`,
  revísalo: el validador lo rechaza para evitar leaks de IDs reales.
