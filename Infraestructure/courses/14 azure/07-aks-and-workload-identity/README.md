# az-07 — AKS y Workload Identity

## Identificación

- **ID:** `az-07-aks-and-workload-identity`
- **Curso:** `azure`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `az-02` (Entra ID / RBAC / Managed Identities), `az-03` (VNet / NSG / Private Link), `az-04` (compute), curso **kubernetes** Nivel 2 y curso AWS ≥ `aws-11` (EKS en profundidad — este módulo asume que ya entiendes IRSA).

## Objetivo

Operar un cluster **AKS** productivo con **identidad por workload** vía **Workload Identity** (sucesor OIDC de Pod Identity v1 — deprecado). Al terminar deberías poder:

- Diseñar un cluster AKS con **control plane administrado** y al menos un modelo de node pool (system + user pool, con la opción de añadir Spot o Virtual Nodes), justificando la elección.
- Elegir entre **Azure CNI**, **Azure CNI Overlay** y **kubenet** (legacy) para un workload dado.
- Darle a un pod permisos Azure **sin secretos** usando **Workload Identity**: `oidc_issuer_enabled`, federated identity credential sobre un User-Assigned Managed Identity, anotaciones `azure.workload.identity/client-id` en el ServiceAccount y label `azure.workload.identity/use: "true"` en el pod.
- Comparar **Workload Identity** con **AAD Pod Identity v1** (deprecado) y plantear un plan de migración por fases.
- Enumerar y justificar los **add-ons** oficiales típicos (App Routing con nginx + managed cert, CSI Secrets Store con Key Vault, Container Insights, Defender, Dapr, GitOps con Flux v2, AGIC).

## Alcance

Este módulo cubre:

- **Modelos de node pool**: system pool obligatorio vs user pools; Spot node pools; Virtual Nodes con ACI para burst.
- **Networking**: Azure CNI (default, da IPs del VNet), Azure CNI Overlay (ahorra IPs del VNet) y kubenet (legacy a extinguir).
- **Autoscaling**: cluster autoscaler clásico; **Node Autoprovisioning (NAP)** inspirado en Karpenter (verifica estado preview vs GA en el momento del curso).
- **Acceso al cluster**: integración Entra ID + Azure RBAC for Kubernetes (no `aws-auth` ni kubeconfig estático con secretos).
- **Workload Identity**: emisor OIDC del cluster + federated identity credential sobre una User-Assigned MI; anotación en el `ServiceAccount` y label en el pod.
- **AAD Pod Identity v1** como ancestro deprecado (NMI DaemonSet + CRDs `AzureIdentity` / `AzureIdentityBinding`): por qué se descarta en greenfield y cómo se migra.
- **Add-ons oficiales**: App Routing, CSI Secrets Store con Azure provider, Container Insights, Microsoft Defender for Containers, Dapr, GitOps con Flux v2 vía `az k8s-extension`, AGIC (Application Gateway Ingress Controller).
- **Upgrades** con surge y max-unavailable.

Lo que **no** cubre (se verá después):

- Observabilidad de AKS con Azure Monitor + App Insights → `az-08`.
- DevSecOps completo (OIDC Federation GitHub Actions → Entra ID, ACR, Defender for Containers, cosign) → `az-10`.
- Multi-cluster federation.

### Nota crítica sobre coste

El **control plane de AKS** en el tier **Free** tiene cero coste por hora, pero **cada node pool** es una **VM Scale Set** y **cuesta como VM** (típicamente 0.05–0.15 USD/hora por VM pequeña + discos + egress). Un cluster "vacío" con un single-node pool `Standard_D2s_v5` ya cuesta ~70 USD/mes solo por los nodos. Si eliges el tier **Standard** (SLA 99.95 %), suma 0.10 USD/hora por cluster.

Este módulo está diseñado para **0 USD de gasto real**: todo se practica con `terraform plan`, validación estructural del HCL, y un cluster local **`kind`** para probar manifiestos Kubernetes. **No se provisiona ningún AKS real** salvo que el alumno decida pagarlo bajo su responsabilidad.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — tres ejemplos para lectura y adaptación local:
  - `01-aks-with-tf/` — llamada a `azurerm_kubernetes_cluster` con `oidc_issuer_enabled = true` + `workload_identity_enabled = true`, system node pool + user node pool opcional, Azure CNI Overlay, add-ons OMS/App Routing/KeyVault secrets provider.
  - `02-workload-identity-to-storage/` — walkthrough anotado: emisor OIDC del cluster, User-Assigned Managed Identity, Federated Identity Credential (`subject = system:serviceaccount:<ns>:<sa>`), anotaciones en el `ServiceAccount` y label en el pod, SDK/CLI validando `az login --federated-token`.
  - `03-flux-extension-for-aks/` — habilitar la extensión **Flux v2** oficial con `az k8s-extension create` + `az k8s-configuration flux create` apuntando a un repo Git público; comparación con instalar Flux "a mano".
- **`activities/`** — dos actividades **independientes**:
  - `01-provision-aks-and-run-app/` — diseñar la provisión AKS (Terraform `plan` + ADR), desplegar la app en `kind` como proxy local y escribir un ADR con 3 decisiones.
  - `02-wi-vs-pod-identity-v1/` — plan de migración razonado de AAD Pod Identity v1 a Workload Identity con manifiestos antes/después y matriz de decisión.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué significa "control plane administrado" en AKS; diferenciar Workload Identity (OIDC federado) de Pod Identity v1 (NMI DaemonSet); diferenciar System-Assigned vs User-Assigned MI y por qué Workload Identity exige User-Assigned. |
| Operativa (sin coste) | Escribir una llamada Terraform al recurso `azurerm_kubernetes_cluster` con OIDC + Workload Identity habilitados; desplegar `Deployment + Service + Ingress` en `kind` que sería compatible con AKS + App Routing; escribir un `ServiceAccount` anotado para Workload Identity. |
| Arquitectónica | Elegir entre system/user node pool, Spot y Virtual Nodes; elegir entre Azure CNI, Azure CNI Overlay y kubenet; elegir entre Workload Identity y AAD Pod Identity v1 (siempre Workload Identity en greenfield). |

## Criterios de evaluación

- Entrega las dos actividades con sus validadores estructurales en verde.
- La **decisión argumentada Workload Identity vs Pod Identity v1** (actividad 02) está defendida con criterios técnicos y menciona la deprecación.
- El ADR de la actividad 01 nombra al menos **3 trade-offs** concretos (p. ej. node pool mix, CNI, autoscaling, acceso Entra RBAC).

## Entregables

- `AKS_PLAN.md` + `main.tf` + manifiestos de app + `ADR.md` (actividad 01).
- `MIGRATION.md` con comparación Workload Identity ↔ Pod Identity v1 + manifiestos anotados antes/después (actividad 02).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, `terraform validate` y `kind`. No se requiere subscription Azure activa. Si en una fase posterior decides provisionar lo diseñado:

- **AKS control plane Free tier**: 0 USD/hora (sin SLA). Standard: 0.10 USD/hora por cluster.
- **Node pools**: coste de VM Scale Set (depende del SKU) + discos + egress.
- **Add-ons**: la mayoría son gratis como feature, pero los recursos subyacentes cobran (Log Analytics por GB ingested para Container Insights, Application Gateway por hora + egress para AGIC, etc.).

## Siguiente módulo

→ `az-08-observability-azure-monitor-app-insights-activity-log` — observabilidad nativa Azure con mirada específica a workloads en AKS.
