# az-07 — Lección: AKS y Workload Identity

> 10 secciones. Mayoritariamente conceptual + bloques de referencia HCL / YAML. Prerrequisitos: `az-02`, `az-03`, `az-04`, curso **kubernetes** Nivel 2 y curso AWS ≥ `aws-11`.

---

## 1. ¿Qué pone Azure encima de "Kubernetes gestionado"?

El valor diferencial de AKS **no** es Kubernetes (eso ya lo da Google y Amazon). El valor es cómo se integra con el resto del plano Azure:

- **Entra ID + Azure RBAC for Kubernetes**: `kubectl` autenticado como usuario Entra, autorización evaluada por Azure RBAC (sin editar `rbac.authorization.k8s.io` a mano).
- **Managed Identities** del cluster para hablar con el resto de Azure (ACR pull, Load Balancer, Key Vault). La identidad del cluster **no** es una service principal con secreto.
- **Workload Identity** para que los pods obtengan tokens Entra sin montar secretos (equivalente OIDC de IRSA en EKS).
- **Add-ons gestionados** (Container Insights, App Routing, Defender, Dapr, Flux) habilitados con una flag.
- **Integración de red** con VNet, Private Link, Application Gateway y Azure Firewall.

> **Idea clave que repetiremos:** la cuenta (subscription) y la identidad (Entra tenant) son el **techo**; el cluster AKS es un recurso más, con su MI y sus RBAC assignments, dentro de ese techo.

---

## 2. Anatomía de un cluster AKS

Un `azurerm_kubernetes_cluster` tiene estas piezas obligatorias:

- **Control plane administrado**: `kube-apiserver`, `etcd`, scheduler y controller-manager los opera Microsoft. Tú no los ves. Expones su API vía un FQDN (`<nombre>-<hash>.hcp.<region>.azmk8s.io`).
- **System node pool**: al menos uno, obligatorio. Hospeda los pods de sistema (CoreDNS, konnectivity, metrics-server, Tunnelfront/Konnectivity-agent) con `CriticalAddonsOnly=true:NoSchedule` por defecto.
- **User node pools** (opcional, 1–N): los pools donde corren tus workloads. Puedes mezclar SKUs, zonas, Spot vs regular y taints.
- **Cluster identity**: `SystemAssigned` o `UserAssigned`. Es la identidad con la que el cluster llama al resto de Azure (ACR pull, LB, etc.). **Preferir `UserAssigned`** si piensas moverlo entre resource groups o compartirlo entre features (Workload Identity exige MI explícita por workload, no la del cluster).
- **Kubelet identity**: identidad separada que ejecuta los pulls de imagen (si usas ACR, aquí asignas `AcrPull`).
- **Networking profile**: `network_plugin = azure | kubenet`, `network_plugin_mode = overlay` (opcional), `network_policy = calico | azure | cilium`.

```
                    ┌──────────────────────────────────────┐
                    │  Control plane (Microsoft-managed)    │
                    │  kube-apiserver / etcd / scheduler    │
                    │  FQDN publico o privado               │
                    └──────────────────┬───────────────────┘
                                       │
                        ┌──────────────┴──────────────┐
                        │   OIDC issuer URL           │  <- habilita WI
                        └──────────────┬──────────────┘
                                       │
             ┌────────────────┬────────┴────────┬────────────────┐
             ▼                ▼                 ▼                ▼
        System pool     User pool "apps"   User pool "spot"  Virtual Nodes
       (CoreDNS, ...)   (D4s, zone 1-3)    (D2s_v5 Spot)     (ACI burst)
             │                │                 │                │
             └──────── VMSS por pool, en el VNet del AKS ────────┘
```

---

## 3. Node pools: system vs user, Spot y Virtual Nodes

Reglas prácticas:

- **Un system pool** es obligatorio y debería ser `Standard_D2s_v5` o superior, en **3 zonas** (`zones = ["1","2","3"]`) y nunca Spot. Ponle `only_critical_addons_enabled = true` para que **nada** de usuario entre allí.
- **Uno o más user pools** para tus workloads. Haz pools por "intención" (CPU-bound, memory-bound, GPU, Spot). Cada pool escala solo (**cluster-autoscaler** por pool), con `min_count` / `max_count`.
- **Spot node pools** son hasta 90 % más baratos pero el nodo puede evaporarse con 30 s de aviso. Úsalos para batch, build runners o workloads idempotentes con PDBs y toleraciones explícitas.
- **Virtual Nodes** (add-on `virtual-node` + ACI) te dan "nodos infinitos" en el momento, pagados por segundo. Buenos para picos; limitados (sin DaemonSets, sin HostPath, sin NodePort).
- **Node Autoprovisioning (NAP)** es el equivalente conceptual a Karpenter en EKS (deja a AKS elegir SKU según los pods pendientes). **Verifica si está en preview o GA** en tu región antes de confiar en él para producción.

Upgrades: cada pool se upgrada por separado con `max_surge` (nodos nuevos añadidos) y, en versiones recientes, `max_unavailable`. Un `max_surge = "33%"` triplica tu factura durante el rolling pero minimiza downtime.

---

## 4. Networking: Azure CNI vs CNI Overlay vs kubenet

| Modo | IPs de pod | Caso típico |
|------|-----------|-------------|
| **Azure CNI** (default) | Del VNet (una IP del subnet por pod) | Pods necesitan hablarse con PaaS vía Private Endpoint; auditoría de origen por IP. |
| **Azure CNI Overlay** | De una CIDR interno (`pod_cidr`), **no** del VNet | Clusters grandes donde el subnet VNet se queda sin IPs; mantiene la performance de Azure CNI. |
| **kubenet** (legacy) | NAT en el host | Evitar en greenfield; sin IP pública por pod y con UDR manual. |

Recomendación 2026: **Azure CNI Overlay** por defecto en greenfield. Mantén Azure CNI "plano" si realmente necesitas que cada pod sea direccionable desde fuera del cluster vía el VNet (poco común). `kubenet` solo en labs.

`network_policy = cilium` (recomendado) o `azure` o `calico` activa NetworkPolicies de Kubernetes. Sin esto, un `NetworkPolicy` que escribas **no hace nada** (fail-open).

---

## 5. Autenticación y autorización al cluster

Dos planos, no mezcles:

- **Autenticación** (quién eres): Entra ID. Habilita `azure_active_directory_role_based_access_control { ... }` con un **Entra admin group** (`admin_group_object_ids`) y `azure_rbac_enabled = true`.
- **Autorización** (qué puedes hacer): **Azure RBAC for Kubernetes**. Role assignments de built-in roles como `Azure Kubernetes Service RBAC Reader | Writer | Admin | Cluster Admin` sobre el scope del cluster (o namespace).

Resultado: `kubectl` reemplaza el user cert por un token Entra; las acciones se evalúan por **Azure** antes de llegar al `kube-apiserver`. **No** editas `ClusterRoleBinding` a mano para humanos.

Para CI/CD: una **User-Assigned Managed Identity** del pipeline (asignada vía federated identity credential OIDC) con rol `AKS RBAC Admin` sobre el cluster. No hay kubeconfig con secretos que rotar.

---

## 6. Workload Identity: el "IRSA" de Azure, pero en OIDC puro

**El problema**: un pod necesita leer un blob de Storage. Opciones malas:

- Un connection string en un `Secret` K8s (secretos rotables en app config).
- La MI del cluster (demasiado ancha, sin granularidad por pod).

**La solución moderna**: Workload Identity.

Piezas:

1. **OIDC issuer** del cluster: `oidc_issuer_enabled = true`. AKS expone `https://<region>.oic.prod-aks.azure.com/<tenant>/<cluster-uid>/`.
2. **User-Assigned Managed Identity** (recurso Azure separado del cluster).
3. **Federated Identity Credential** sobre esa MI:
   ```
   issuer   = oidc_issuer_url del cluster
   subject  = "system:serviceaccount:<namespace>:<serviceaccount>"
   audience = ["api://AzureADTokenExchange"]
   ```
4. **Role assignments** Azure sobre la MI (`Storage Blob Data Reader`, `Key Vault Secrets User`, etc.).
5. **ServiceAccount K8s** con anotación `azure.workload.identity/client-id: <client_id de la MI>`.
6. **Pod** con label `azure.workload.identity/use: "true"` y `serviceAccountName: <sa>`.

Flujo en runtime:

- El webhook `azure-workload-identity` (del addon `workload_identity_enabled = true`) inyecta en el pod un **projected token** del SA + variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_FEDERATED_TOKEN_FILE`.
- El SDK (Azure Identity ≥ reciente) usa `WorkloadIdentityCredential`: envía el token proyectado al endpoint de Entra, Entra verifica (issuer OIDC + subject federado) y devuelve un **access token** para la MI.
- El pod llama a la API Azure con ese access token. Sin secretos.

Trust: la federación compara **issuer** (URL OIDC del cluster) + **subject** (`system:serviceaccount:<ns>:<sa>`). Si el SA/ns no coincide, no hay token. Si cambias el nombre del SA, actualiza la federated identity credential.

---

## 7. ¿Por qué NO Pod Identity v1?

**AAD Pod Identity v1** es el ancestro deprecado. Sus piezas:

- **NMI (Node Managed Identity)** DaemonSet que intercepta llamadas al IMDS (169.254.169.254) desde los pods.
- **MIC (Managed Identity Controller)** Deployment que asigna/retira identidades a VMs del cluster al ritmo de los pods.
- CRDs **`AzureIdentity`** (apunta a una MI por `clientId`/`resourceId`) y **`AzureIdentityBinding`** (une un label `aadpodidbinding=<sel>` del pod a una `AzureIdentity`).

Problemas que motivaron su deprecación:

1. **Interceptar IMDS** es frágil: cualquier cambio del CNI o del nodo puede romperlo. Debuggearlo requiere entender iptables en el host.
2. **Race condition** entre pod `Pending` → MIC asigna la MI al nodo → kubelet programa el pod. Los pods de arranque muy rápidos a veces no veían la MI.
3. **MI compartida por nodo**: si dos pods del mismo nodo necesitaban MIs distintas, los side-effects eran delicados.
4. **Alcance Azure-only** por diseño; no era OIDC estándar.
5. Microsoft **anunció deprecación** y el equipo recomienda migrar **todo** a Workload Identity.

Workload Identity resuelve 1 y 2 (nada de IMDS: el pod recibe directamente un token proyectado), 3 (una MI por SA, inherente a la federación por subject) y 4 (es OIDC federation estándar; mismas skills que IRSA / GitHub OIDC).

---

## 8. Migrar de Pod Identity v1 a Workload Identity

Patrón **dual-run**, por workload:

### Fase 1 — Preparación (una vez por cluster)

- Habilitar en el cluster `oidc_issuer_enabled = true` y `workload_identity_enabled = true` (recrea el cluster si no estaban desde el día cero — vale la pena planificarlo).
- Instalar el **webhook** (ya viene con el flag anterior; verificar que los pods `azure-wi-webhook-*` están `Running`).
- Dejar NMI/MIC en pie (los pods existentes siguen usando Pod Identity v1).

### Fase 2 — Por workload

1. Crear una **User-Assigned MI** nueva (o reutilizar la que ya usaba la `AzureIdentity`).
2. Añadir una **Federated Identity Credential**:
   - `issuer` = OIDC issuer URL del cluster.
   - `subject` = `system:serviceaccount:<ns>:<sa>`.
   - `audience` = `api://AzureADTokenExchange`.
3. Anotar el `ServiceAccount` con `azure.workload.identity/client-id`.
4. Añadir el label `azure.workload.identity/use: "true"` al pod template.
5. Rollout. El SDK Azure Identity (reciente) elegirá `WorkloadIdentityCredential` automáticamente.
6. Validar: `kubectl logs` + llamada real a Azure (p. ej. `az storage blob list` desde el pod).
7. Retirar la anotación `aadpodidbinding` y los CRDs `AzureIdentity[Binding]` **de ese workload**.

### Fase 3 — Cleanup (cuando todos los workloads migraron)

- Desinstalar NMI/MIC.
- Borrar las CRDs `AzureIdentity` y `AzureIdentityBinding` (y `AzurePodIdentityException` si usaste).
- Borrar los role assignments a VMs/VMSS que Pod Identity v1 había estampado (eran side-effects del MIC).

### Rollback (si algo sale mal mid-cutover)

- El pod todavía tiene la etiqueta `aadpodidbinding` original — basta quitar el label `azure.workload.identity/use` y el `serviceAccountName` nuevo, y Pod Identity v1 vuelve a servir.

---

## 9. Add-ons oficiales que vale la pena habilitar

Catálogo mínimo que suele acompañar a un AKS "productivo":

- **App Routing** (`web_app_routing { ... }`): nginx como ingress controller gestionado por Microsoft, con integración opcional a Azure DNS y managed certificates (DigiCert). Alternativa: AGIC (Application Gateway Ingress Controller) si ya tienes Application Gateway por otra razón.
- **CSI Secrets Store con Azure provider** (`key_vault_secrets_provider { secret_rotation_enabled = true }`): monta secretos de Key Vault como volumen; también puede sincronizarlos a `Secret` K8s para apps que no leen de FS.
- **Container Insights** (`oms_agent { ... }`): envía logs y métricas de nodos y pods a un **Log Analytics Workspace**. Cuidado con la factura (ingesta por GB).
- **Microsoft Defender for Containers** (`microsoft_defender { ... }`): vulnerability scanning (ACR + runtime) y detections (eBPF).
- **Dapr** (`az k8s-extension create --extension-type Microsoft.Dapr`): building blocks (state, pub/sub, bindings) sin acoplar la app al vendor.
- **GitOps con Flux v2** (`az k8s-extension create --extension-type microsoft.flux`): Flux instalado por Microsoft, con `az k8s-configuration flux create` apuntando a tu repo Git. Reemplaza instalaciones "a mano" de Flux o Argo.
- **AGIC** (`ingress_application_gateway { ... }`): si decides App Gateway en vez de App Routing.

Cada add-on es un **extensión** administrada: Microsoft la upgradea con el cluster, pero tus **configuraciones** sí son tuyas.

---

## 10. Comparativa AKS vs EKS vs GKE (resumen operativo)

| Dimensión | AKS | EKS | GKE |
|-----------|-----|-----|-----|
| Control plane coste | 0 USD (Free) / 0.10 USD/h (Standard) | 0.10 USD/h | 0.10 USD/h (zonal), más Autopilot |
| Identidad por pod | **Workload Identity** (OIDC federation sobre UA-MI) | **IRSA** (OIDC) / Pod Identity (API) | **Workload Identity** (OIDC a GSA) |
| Autoscaling de nodos | CAS; **NAP** (verificar GA) | CAS; **Karpenter** (GA) | CAS; **Autopilot** (serverless nodes) |
| CNI | Azure CNI / Azure CNI Overlay / kubenet | VPC CNI (default) | GKE CNI con alias IPs |
| Ingress managed | App Routing (nginx) o AGIC | ALB Controller | GKE Ingress / Gateway API |
| GitOps nativo | Flux v2 vía `az k8s-extension` | — (instalas Argo/Flux tú) | Config Sync (Anthos) |
| Policy | Azure Policy for AKS (OPA/Rego debajo) | OPA / Kyverno (tú lo instalas) | Policy Controller (OPA) |
| Secretos | CSI Secrets Store con Azure provider | CSI Secrets Store con AWS provider | GKE Secrets Store CSI con GCP |
| Observabilidad | Container Insights + App Insights | Container Insights (CloudWatch) + ADOT | GKE Logs & Metrics (Cloud Logging/Monitoring) |

Puntos divergentes importantes:

- Workload Identity de AKS y de GKE son **conceptualmente idénticos** (OIDC federation hacia una MI/GSA). IRSA de EKS también. Las skills se transfieren.
- Pod Identity "legacy" existió en los tres (`AAD Pod Identity v1` en AKS, `kube2iam/kiam` en EKS, "Node identity" en GKE). Todos deprecados o descartados.
- AKS tiene **GitOps nativo** (Flux) como una flag; en EKS lo instalas tú.
- AKS tiene **Azure Policy for AKS** gestionado; en EKS instalas Gatekeeper tú.

---

> **Siguientes pasos.** Haz las dos actividades (son independientes):
>
> - `activities/01-provision-aks-and-run-app/` — Terraform + ADR + kind.
> - `activities/02-wi-vs-pod-identity-v1/` — comparación y migración.
