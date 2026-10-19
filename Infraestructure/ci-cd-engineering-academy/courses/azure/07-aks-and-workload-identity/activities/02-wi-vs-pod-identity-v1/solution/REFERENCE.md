# REFERENCE — az-07-02-wi-vs-pod-identity-v1

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `manifests/sa-pod-identity-v1.yaml` (modelo)

```yaml
# ANTES: workload usando AAD Pod Identity v1.
#
# Prerequisito en el cluster:
#   - NMI DaemonSet corriendo en todos los nodos user.
#   - MIC Deployment en kube-system.
#
# Managed Identity (fuera del cluster, ya existente):
#   name:       mi-az07-app
#   clientId:   33333333-3333-3333-3333-333333333333
#   resourceID: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-az07-demo/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-az07-app
#
# Role assignments sobre la MI (minimos):
#   - Storage Blob Data Reader  sobre staz07demodata
#   - Storage Blob Data Contributor  sobre staz07demodata (si escribe)
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentity
metadata:
  name: app
  namespace: apps
spec:
  type: 0  # 0 = User-Assigned MSI
  resourceID: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-az07-demo/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-az07-app
  clientID: 33333333-3333-3333-3333-333333333333
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: app-binding
  namespace: apps
spec:
  azureIdentity: app
  selector: app-pi  # cualquier pod con label aadpodidbinding=app-pi usara la MI.
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: apps
  # Nota: Pod Identity v1 NO usa anotaciones en el SA. El binding va por label en el pod.
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
        # Label critico de Pod Identity v1: lo evalua MIC + NMI.
        aadpodidbinding: app-pi
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: mcr.microsoft.com/azure-cli:latest
          command:
            - /bin/sh
            - -c
            - |
              set -eu
              # NMI intercepta IMDS (169.254.169.254) y responde con un token
              # para la MI vinculada por AzureIdentityBinding al label aadpodidbinding.
              az login --identity --username 33333333-3333-3333-3333-333333333333
              az storage blob list \
                --account-name staz07demodata \
                --container-name data \
                --auth-mode login \
                --output table
              sleep 3600
```

## `manifests/sa-wi.yaml` (modelo)

```yaml
# DESPUES: mismo workload, misma MI, misma politica Azure.
# Cambia la trust (federation OIDC) y como el pod obtiene credenciales.
#
# Managed Identity (sin cambios):
#   name:       mi-az07-app
#   clientId:   33333333-3333-3333-3333-333333333333
#
# Role assignments sobre la MI (sin cambios):
#   - Storage Blob Data Reader  sobre staz07demodata
#
# Federated Identity Credential sobre mi-az07-app:
#   issuer:   https://westeurope.oic.prod-aks.azure.com/11111111-1111-1111-1111-111111111111/aaaabbbb-cccc-dddd-eeee-ffff00001111/
#   subject:  system:serviceaccount:apps:app
#   audience: api://AzureADTokenExchange
#
# Terraform equivalente:
#
#   resource "azurerm_federated_identity_credential" "app" {
#     name                = "fic-app-apps-ns"
#     resource_group_name = "rg-az07-demo"
#     parent_id           = azurerm_user_assigned_identity.app.id
#     audience            = ["api://AzureADTokenExchange"]
#     issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
#     subject             = "system:serviceaccount:apps:app"
#   }
#
# Prerequisito en el cluster:
#   - oidc_issuer_enabled = true, workload_identity_enabled = true.
#   - Webhook azure-wi-webhook-* corriendo (lo instala el flag anterior).
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: apps
  annotations:
    azure.workload.identity/client-id: "33333333-3333-3333-3333-333333333333"
    # tenant-id es opcional si el cluster lo infiere; aqui explicito:
    azure.workload.identity/tenant-id: "11111111-1111-1111-1111-111111111111"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
        # Label critico: activa el webhook de Workload Identity para este pod.
        # Sin este label, NO se inyectan las variables ni el projected token.
        azure.workload.identity/use: "true"
      # Nota: NO hay label aadpodidbinding. Si lo dejas por error, Pod Identity v1
      # (si todavia esta en el cluster) competira con Workload Identity y veras
      # comportamiento no determinista en los primeros reinicios.
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: mcr.microsoft.com/azure-cli:latest
          command:
            - /bin/sh
            - -c
            - |
              set -eu
              # Variables inyectadas por el webhook azure-workload-identity:
              #   AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE,
              #   AZURE_AUTHORITY_HOST.
              az login --service-principal \
                --username "$AZURE_CLIENT_ID" \
                --tenant   "$AZURE_TENANT_ID" \
                --federated-token "$(cat $AZURE_FEDERATED_TOKEN_FILE)"
              az storage blob list \
                --account-name staz07demodata \
                --container-name data \
                --auth-mode login \
                --output table
              sleep 3600
```

## `docs/MIGRATION.md` (modelo, extracto)

```markdown
# Migración AAD Pod Identity v1 → Workload Identity

## Comparación Pod Identity v1 vs Workload Identity

| Dimensión                      | Pod Identity v1                                   | Workload Identity                                        |
|--------------------------------|---------------------------------------------------|----------------------------------------------------------|
| Mecanismo de token             | NMI DaemonSet intercepta IMDS → MI asignada a VM  | Projected token del SA + federation OIDC → MI            |
| Setup por cluster              | Instalar NMI + MIC + CRDs                         | Flag `workload_identity_enabled` + `oidc_issuer_enabled` |
| Trust configuration            | `AzureIdentityBinding` por label del pod          | Federated Identity Credential (issuer+subject+audience)  |
| Reuso de MI cross-cluster      | Difícil (MIC asigna la MI a VMs del cluster)      | Trivial (misma MI + FIC distinta por cluster)            |
| Compatibilidad fuera de AKS    | No                                                | No (específico AKS, pero el patrón OIDC es portable)     |
| SDK Azure mínimo               | Antiguo (ya en los SDKs desde hace años)          | Reciente (`WorkloadIdentityCredential`)                  |
| Deprecación                    | Deprecado por Microsoft                           | Camino oficial recomendado                               |
| Observabilidad                 | `AADServicePrincipalSignInLogs` + tráfico IMDS    | `AADServicePrincipalSignInLogs` con `federatedCredentialId` |
| Race conditions arranque pod   | Sí (MIC puede llegar tarde)                       | No (token proyectado disponible desde `startupProbe`)    |
| Dependencia de iptables        | Sí (NMI reescribe tráfico a IMDS)                 | No                                                       |

## Plan de migración por fases

### Fase 1 — Dual-run (preparación)
- Verificar que el cluster tiene `oidc_issuer_enabled = true` y `workload_identity_enabled = true`.
  Si no, planificar su habilitación: en Terraform es un apply en caliente,
  pero el webhook tarda unos minutos en estar `Ready`.
- Dejar NMI/MIC + CRDs `AzureIdentity[Binding]` en pie.
- Crear la Federated Identity Credential sobre la MI, con el `subject` exacto
  `system:serviceaccount:apps:app`.
- Validar con un pod *canary* nuevo que la federation funciona (contenedor que
  llama a Azure y hace `az sts show`).

### Fase 2 — Cutover (por workload)
- Para el workload concreto: aplicar `sa-wi.yaml` (anotación en SA + label
  Workload Identity en pod + eliminar `aadpodidbinding`).
- Rollout del Deployment. Observar `AADServicePrincipalSignInLogs`: los sign-in
  deben traer `federatedCredentialId` en lugar de `tokenIssuerType = MSI`.
- Validar comportamiento end-to-end (la app realmente lee del Storage).

### Fase 3 — Rollback (si algo sale mal)
- Re-aplicar `sa-pod-identity-v1.yaml` del workload. El pod vuelve a tener
  el label `aadpodidbinding` y NMI vuelve a servir.
- Postmortem: ¿SDK muy viejo? ¿Webhook caído? ¿FIC con `subject` incorrecto?

### Fase 4 — Cleanup (cuando TODOS los workloads migraron)
- Desinstalar NMI DaemonSet y MIC Deployment.
- Borrar las CRDs `AzureIdentity`, `AzureIdentityBinding`, `AzurePodIdentityException`.
- Borrar los role assignments a VMSS que MIC estampó (eran side-effects: ya no se usan).
- Documentar en el ADR que el cluster es "pure Workload Identity".

## Matriz de decisión por escenario

### Escenario A — Greenfield, cluster AKS nuevo
**Decisión:** Workload Identity, sin considerar Pod Identity v1.
**Justificación:** Pod Identity v1 está deprecado. No tiene sentido empezar en 2026
con un camino sin futuro. Setup es más corto y la trust es más limpia.

### Escenario B — Legacy, 20 workloads con Pod Identity v1
**Decisión:** Dual-run por 1–2 sprints, migrar workload a workload, cleanup final.
**Justificación:** La migración vale la pena por la deprecación anunciada y porque
elimina race conditions. Pero migrar los 20 "big bang" aumenta el blast radius.
Dual-run permite rollback por workload.

### Escenario C — Workload cross-platform (corre también en Container Apps)
**Decisión:** NI Pod Identity v1 NI Workload Identity "puros". Para la réplica
AKS, Workload Identity. Para la réplica Container Apps, **Managed Identity del
Container App** (system-assigned o user-assigned del propio recurso).
**Justificación:** Workload Identity es específico AKS. Container Apps tiene su
propio mecanismo (hermano conceptual: credenciales temporales inyectadas por el
runtime). El código Azure SDK no cambia si usas `DefaultAzureCredential`:
ambos patrones exponen credenciales por el canal estándar.

## Límite claro: lo que Workload Identity NO resuelve

- No funciona fuera de AKS (Container Apps, Functions, VM tienen sus propios
  patrones; todos basados en MI, pero cada uno con su setup).
- No reemplaza una buena política Azure mínima en la MI (sigue siendo tu problema
  decidir si va `Storage Blob Data Reader` o `Contributor`).
- No elimina la necesidad de **una MI por workload crítico**: compartir MI entre
  10 workloads con requisitos distintos vuelve al mismo problema de Pod Identity v1
  (política demasiado ancha).
- No es automático: hay que **habilitar OIDC + Workload Identity en el cluster**,
  **crear la FIC con el `subject` exacto** y **asegurarse de que el SDK es reciente**.

## 7 preguntas antes de autorizar una migración

1. ¿El SDK Azure del workload soporta `WorkloadIdentityCredential`? ¿Qué versión mínima?
2. ¿Está el flag `workload_identity_enabled = true` en el cluster y los pods del
   webhook `azure-wi-webhook-*` en estado `Running`?
3. ¿La Federated Identity Credential tiene exactamente `subject = "system:serviceaccount:<ns>:<sa>"`
   y `audience = "api://AzureADTokenExchange"`?
4. ¿Hay observabilidad en `AADServicePrincipalSignInLogs` para distinguir ambos
   flujos durante dual-run (`federatedCredentialId` presente vs ausente)?
5. ¿El workload tiene SLO que no tolera un rollout fallido? Si sí, canary primero.
6. ¿Hay otros workloads que reusarían la misma MI? ¿Justifica consolidar la FIC
   o se queda cada workload con la suya?
7. ¿Qué pasa con los jobs batch de > 1 h que renuevan credenciales a medio ejecutar?
   (Workload Identity renueva automático; verificar que el SDK lo gestiona.)
```

## Comentarios de autoevaluación

- Si tu tabla de comparación tiene **menos de 7 filas**, repítela.
- Si tu plan por fases **no** contempla rollback **ni** cleanup final de NMI/MIC, repítelo.
- Si el Escenario C sugiere "Workload Identity en Container Apps", repítelo: Container
  Apps tiene su propio mecanismo de MI (no Workload Identity).
- Si tu `sa-wi.yaml` deja `aadpodidbinding` en el pod template, es un bug que
  causará comportamiento no determinista durante dual-run.
